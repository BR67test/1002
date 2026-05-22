#!/bin/bash
# ============================================================
# SRV-ZBX-01 — СЕРВЕР МОНИТОРИНГА ZABBIX (ФИНАЛЬНЫЙ)
# ОС: ALT Server 10
# IP: 10.0.10.13/24, шлюз: 10.0.10.1
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА SRV-ZBX-01 (ZABBIX)"
echo "========================================="

# ----------------------------------------------------------
# 1. Обновление и пакеты
# ----------------------------------------------------------
echo "[1/7] Обновление и установка пакетов..."
apt-get update && apt-get dist-upgrade -y
apt-get install -y postgresql16 postgresql16-server apache2 php8.2 php8.2-pgsql php8.2-mbstring php8.2-xml php8.2-bcmath php8.2-ldap zabbix-server-pgsql zabbix-agent chrony net-tools openssh-server wget tar

# ----------------------------------------------------------
# 2. Сеть
# ----------------------------------------------------------
echo "[2/7] Настройка сети..."
mkdir -p /etc/net/ifaces/ens18

cat > /etc/net/ifaces/ens18/options << 'EOF'
TYPE=eth
BOOTPROTO=static
ONBOOT=yes
EOF

echo '10.0.10.13/24' > /etc/net/ifaces/ens18/ipv4address

mkdir -p /etc/net/ifaces/default
echo '10.0.10.1' > /etc/net/ifaces/default/ipv4route
echo "nameserver 10.0.10.10" > /etc/resolv.conf

systemctl restart network

echo ""
echo "=== Проверка связи ==="
ping -c 2 10.0.10.1

# ----------------------------------------------------------
# 3. Время
# ----------------------------------------------------------
echo "[3/7] Настройка времени..."
systemctl enable --now chronyd
sleep 2
chronyc makestep || true

# ----------------------------------------------------------
# 4. PostgreSQL
# ----------------------------------------------------------
echo "[4/7] Настройка PostgreSQL..."

systemctl enable --now postgresql
sleep 3

su - postgres -c "psql -c \"CREATE USER zabbix WITH PASSWORD 'Zabbix123!';\""
su - postgres -c "psql -c \"CREATE DATABASE zabbix OWNER zabbix;\""

# ----------------------------------------------------------
# 5. Веб-интерфейс Zabbix
# ----------------------------------------------------------
echo "[5/7] Установка веб-интерфейса..."

cd /tmp
wget -q https://cdn.zabbix.com/zabbix/sources/stable/6.0/zabbix-6.0.0.tar.gz
tar -xzf zabbix-6.0.0.tar.gz
mkdir -p /usr/share/zabbix
cp -r zabbix-6.0.0/ui/* /usr/share/zabbix/
chown -R apache2:apache2 /usr/share/zabbix

a2enmod php8.2
systemctl restart httpd2

# ----------------------------------------------------------
# 6. Zabbix Server
# ----------------------------------------------------------
echo "[6/7] Настройка Zabbix Server..."

zcat /usr/share/doc/zabbix-server-pgsql-*/create.sql.gz | su - postgres -c "psql zabbix"

cat > /etc/zabbix/zabbix_server.conf << 'EOF'
DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=Zabbix123!
ListenPort=10051
EOF

systemctl enable --now zabbix-server

# ----------------------------------------------------------
# 7. Zabbix Agent и веб-сервер
# ----------------------------------------------------------
echo "[7/7] Настройка Zabbix Agent и Apache..."

cat > /etc/zabbix/zabbix_agentd.conf << 'EOF'
Server=127.0.0.1
ServerActive=127.0.0.1
Hostname=SRV-ZBX-01
EOF

systemctl enable --now zabbix-agent

cat > /etc/httpd2/conf/sites-available/zabbix.conf << 'EOF'
Alias /zabbix /usr/share/zabbix
<Directory "/usr/share/zabbix">
    Options FollowSymLinks
    AllowOverride None
    Require all granted
    php_value max_execution_time 300
    php_value memory_limit 128M
    php_value post_max_size 16M
    php_value upload_max_filesize 2M
    php_value date.timezone Europe/Moscow
</Directory>
EOF

ln -sf /etc/httpd2/conf/sites-available/zabbix.conf /etc/httpd2/conf/sites-enabled/
systemctl restart httpd2

# ----------------------------------------------------------
# Финал
# ----------------------------------------------------------
echo ""
echo "========================================="
echo "  SRV-ZBX-01 ГОТОВ"
echo "========================================="
echo ""
echo "Zabbix: http://10.0.10.13/zabbix"
echo "БД: zabbix / Zabbix123!"
echo "Логин: Admin / zabbix"
echo ""
echo "Статусы:"
echo "  PostgreSQL:    $(systemctl is-active postgresql)"
echo "  Zabbix Server: $(systemctl is-active zabbix-server)"
echo "  Zabbix Agent:  $(systemctl is-active zabbix-agent)"
echo "  Apache2:       $(systemctl is-active httpd2)"
