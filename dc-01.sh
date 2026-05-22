#!/bin/bash
# ============================================================
# SRV-DC-01 — КОНТРОЛЛЕР ДОМЕНА
# ОС: ALT Server 10
# IP: 10.0.10.10/24
# Шлюз: 10.0.10.1
# Домен: br67core.local
# Пароль администратора: P@ssw0rd!
# Роли: Samba AD DC (встроенный DNS), DHCP
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА SRV-DC-01"
echo "  Домен: br67core.local"
echo "========================================="

# ----------------------------------------------------------
# 1. Обновление и пакеты
# ----------------------------------------------------------
echo "[1/7] Обновление и установка пакетов..."
apt-get update && apt-get dist-upgrade -y
apt-get install -y task-samba-dc dhcp-server chrony net-tools openssh-server

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
echo "[3/7] Настройка времени..."
systemctl enable --now chronyd
chronyc makestep

# ----------------------------------------------------------
# 4. Развёртывание домена (встроенный DNS Samba)
# ----------------------------------------------------------
echo "[4/7] Развёртывание Samba AD DC..."

rm -f /etc/samba/smb.conf
rm -rf /var/lib/samba/private/*

samba-tool domain provision \
    --use-rfc2307 \
    --realm=BR67CORE.LOCAL \
    --domain=BR67CORE \
    --adminpass='P@ssw0rd!' \
    --server-role=dc \
    --dns-backend=SAMBA_INTERNAL \
    --host-name=srv-dc-01

# ----------------------------------------------------------
# 5. Запуск Samba
# ----------------------------------------------------------
echo "[5/7] Запуск Samba..."

# Копируем конфиг в стандартное место
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

systemctl enable --now samba

# Настройка DNS forwarders
samba-tool dns zoneoptions 127.0.0.1 --option=forwarder --value=8.8.8.8
samba-tool dns zoneoptions 127.0.0.1 --option=forwarder --value=77.88.8.8

echo ""
echo "=== Проверка домена ==="
samba-tool domain level show

# ----------------------------------------------------------
# 6. Настройка DHCP
# ----------------------------------------------------------
echo "[6/7] Настройка DHCP-сервера..."

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
# 7. Тестовые пользователи
# ----------------------------------------------------------
echo "[7/7] Создание тестовых пользователей..."

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
echo "Пароль администратора: P@ssw0rd!"
echo "Пользователи: user1, user2, admin (Pass123!)"
echo ""
echo "=== Статусы служб ==="
echo "Samba:  $(systemctl is-active samba)"
echo "DHCP:   $(systemctl is-active dhcpd)"
echo "Chrony: $(systemctl is-active chronyd)"
echo ""
echo "=== Проверка DNS ==="
host -t A br67core.local 127.0.0.1
echo ""
echo "=== Проверка Kerberos ==="
echo "P@ssw0rd!" | kinit administrator@BR67CORE.LOCAL && klist
