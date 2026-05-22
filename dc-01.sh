#!/bin/bash
# ============================================================
# SRV-DC-01 — КОНТРОЛЛЕР ДОМЕНА
# ОС: ALT Server 10
# IP: 10.0.10.10/24
# Шлюз: 10.0.10.1
# Домен: br67core.local
# Пароль администратора: P@ssw0rd!
# Роли: Samba AD DC, DNS, DHCP
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА SRV-DC-01"
echo "  Контроллер домена Samba AD DC"
echo "  Домен: br67core.local"
echo "========================================="

# ----------------------------------------------------------
# 1. Обновление и пакеты
# ----------------------------------------------------------
echo "[1/8] Обновление и установка пакетов..."
apt-get update && apt-get dist-upgrade -y
apt-get install -y task-samba-dc bind dhcp-server chrony net-tools openssh-server

# ----------------------------------------------------------
# 2. Сеть
# ----------------------------------------------------------
echo "[2/8] Настройка сети..."
mkdir -p /etc/net/ifaces/ens18

cat > /etc/net/ifaces/ens18/options << 'EOF'
TYPE=eth
BOOTPROTO=static
ONBOOT=yes
EOF

echo '10.0.10.10/24' > /etc/net/ifaces/ens18/ipv4address

mkdir -p /etc/net/ifaces/default
echo '10.0.10.1' > /etc/net/ifaces/default/ipv4route

echo "nameserver 127.0.0.1" > /etc/resolv.conf

systemctl restart network

echo ""
echo "=== Проверка связи с GW-01 ==="
ping -c 2 10.0.10.1 && echo "GW-01 доступен" || echo "Нет связи с GW-01"

# ----------------------------------------------------------
# 3. Синхронизация времени
# ----------------------------------------------------------
echo "[3/8] Настройка времени..."
systemctl enable --now chronyd
chronyc makestep

# ----------------------------------------------------------
# 4. Развёртывание контроллера домена
# ----------------------------------------------------------
echo "[4/8] Развёртывание Samba AD DC..."

rm -f /etc/samba/smb.conf
rm -rf /var/lib/samba/private/*

samba-tool domain provision \
    --use-rfc2307 \
    --realm=BR67CORE.LOCAL \
    --domain=BR67CORE \
    --adminpass='P@ssw0rd!' \
    --server-role=dc \
    --dns-backend=BIND9_DLZ \
    --host-name=srv-dc-01

# ----------------------------------------------------------
# 5. Настройка DNS (Bind9)
# ----------------------------------------------------------
echo "[5/8] Настройка DNS (Bind9)..."

cp /var/lib/samba/bind-dns/named.conf /etc/bind/named.conf.local

cat >> /etc/bind/named.conf << 'EOF'
include "/etc/bind/named.conf.local";
EOF

cat > /etc/bind/named.conf.options << 'EOF'
options {
    directory "/var/cache/bind";
    forwarders {
        8.8.8.8;
        77.88.8.8;
    };
    allow-query { any; };
    dnssec-validation no;
    listen-on { any; };
};
EOF

systemctl enable --now bind

# ----------------------------------------------------------
# 6. Запуск Samba и проверка
# ----------------------------------------------------------
echo "[6/8] Запуск Samba..."

systemctl enable --now samba
systemctl enable --now krb5-kdc

echo ""
echo "=== Проверка домена ==="
samba-tool domain level show

# ----------------------------------------------------------
# 7. Настройка DHCP
# ----------------------------------------------------------
echo "[7/8] Настройка DHCP-сервера..."

cat > /etc/dhcp/dhcpd.conf << 'EOF'
default-lease-time 86400;
max-lease-time 604800;
authoritative;

subnet 10.0.20.0 netmask 255.255.255.0 {
    range 10.0.20.50 10.0.20.200;
    option routers 10.0.20.1;
    option subnet-mask 255.255.255.0;
    option domain-name-servers 10.0.10.10;
    option domain-name "br67core.local";
    option netbios-name-servers 10.0.10.10;
}
EOF

cat > /etc/sysconfig/dhcpd << 'EOF'
DHCPDARGS="ens18"
EOF

systemctl enable --now dhcpd

# ----------------------------------------------------------
# 8. Тестовые пользователи
# ----------------------------------------------------------
echo "[8/8] Создание тестовых пользователей..."

for user in user1 user2 admin; do
    samba-tool user create $user "Pass123!" --given-name=$user --surname=Test
done

# ----------------------------------------------------------
# Финал
# ----------------------------------------------------------
echo ""
echo "========================================="
echo "  НАСТРОЙКА SRV-DC-01 ЗАВЕРШЕНА"
echo "========================================="
echo ""
echo "Домен: BR67CORE.LOCAL"
echo "Пароль администратора домена: P@ssw0rd!"
echo "Пользователи: user1, user2, admin (пароль: Pass123!)"
echo ""
echo "=== Статусы служб ==="
echo "Samba:  $(systemctl is-active samba)"
echo "Bind9:  $(systemctl is-active bind)"
echo "DHCP:   $(systemctl is-active dhcpd)"
echo "Chrony: $(systemctl is-active chronyd)"
echo ""
echo "=== Проверка DNS ==="
host -t A br67core.local 127.0.0.1
echo ""
echo "=== Проверка Kerberos ==="
echo "P@ssw0rd!" | kinit administrator@BR67CORE.LOCAL && klist
