#!/bin/bash
# ============================================================
# Скрипт полной настройки маршрутизатора GW-01
# ОС: ALT Linux 10
# Интерфейсы: ens18 (WAN), ens19 (LAN — 10.0.0.1/24)
# Роль: NAT, Firewall, DNS-кэш, DHCP Relay
# Серверный сегмент: VLAN 10 (10.0.10.0/24)
# Пользовательский сегмент: VLAN 20 (10.0.20.0/24)
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА GW-01 (МАРШРУТИЗАТОР)"
echo "  ens18 -> WAN | ens19 -> LAN"
echo "========================================="

# ----------------------------------------------------------
# 1. Обновление системы и установка пакетов
# ----------------------------------------------------------
echo "[1/7] Обновление системы и установка пакетов..."
apt-get update && apt-get dist-upgrade -y
apt-get install -y iptables net-tools openssh-server chrony tcpdump dnsmasq dhcp-server

# ----------------------------------------------------------
# 2. Синхронизация времени
# ----------------------------------------------------------
echo "[2/7] Настройка синхронизации времени..."
systemctl enable --now chronyd

# ----------------------------------------------------------
# 3. Настройка внутреннего интерфейса ens19
# ----------------------------------------------------------
echo "[3/7] Настройка сетевого интерфейса ens19 (LAN)..."
mkdir -p /etc/net/ifaces/ens19

cat > /etc/net/ifaces/ens19/options << 'EOF'
TYPE=eth
BOOTPROTO=static
ONBOOT=yes
EOF

cat > /etc/net/ifaces/ens19/ipv4address << 'EOF'
10.0.0.1/24
EOF

systemctl restart network

# ----------------------------------------------------------
# 4. Включение IP-форвардинга
# ----------------------------------------------------------
echo "[4/7] Включение IP-форвардинга..."
echo 1 > /proc/sys/net/ipv4/ip_forward

cat >> /etc/sysctl.conf << 'EOF'
net.ipv4.ip_forward = 1
EOF

sysctl -p

# ----------------------------------------------------------
# 5. Настройка iptables (Firewall + NAT)
# ----------------------------------------------------------
echo "[5/7] Настройка межсетевого экрана и NAT..."

cat > /etc/iptables.sh << 'IPTEOF'
#!/bin/bash

# Очистка всех правил
iptables -F
iptables -t nat -F
iptables -t mangle -F

# Политики по умолчанию
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Разрешаем loopback
iptables -A INPUT -i lo -j ACCEPT

# Разрешаем установленные и связанные соединения
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Разрешаем SSH из локальной сети (ens19)
iptables -A INPUT -i ens19 -p tcp --dport 22 -j ACCEPT

# Разрешаем ICMP (ping) из локальной сети
iptables -A INPUT -i ens19 -p icmp -j ACCEPT

# Разрешаем форвардинг из локальной сети во внешнюю
iptables -A FORWARD -i ens19 -o ens18 -j ACCEPT

# NAT (маскарадинг) для выхода в интернет
iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE

# Защита от простых сканирований портов
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
IPTEOF

chmod +x /etc/iptables.sh
/etc/iptables.sh

# Сохраняем правила
iptables-save > /etc/sysconfig/iptables

# Автозапуск через systemd
cat > /etc/systemd/system/iptables.service << 'EOF'
[Unit]
Description=IPTables Firewall
After=network.target

[Service]
Type=oneshot
ExecStart=/etc/iptables.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable iptables.service

# ----------------------------------------------------------
# 6. Настройка dnsmasq (кэширующий DNS)
# ----------------------------------------------------------
echo "[6/7] Настройка кэширующего DNS (dnsmasq)..."
cat > /etc/dnsmasq.conf << 'EOF'
interface=ens19
server=8.8.8.8
server=77.88.8.8
cache-size=500
log-queries
log-facility=/var/log/dnsmasq.log
EOF

systemctl enable --now dnsmasq

# ----------------------------------------------------------
# 7. Настройка DHCP Relay (dhcrelay)
# ----------------------------------------------------------
echo "[7/7] Настройка DHCP Relay..."

cat > /etc/systemd/system/dhcrelay.service << 'EOF'
[Unit]
Description=DHCP Relay Agent (dhcrelay)
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/dhcrelay -q -i ens19 10.0.10.10
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now dhcrelay

# ----------------------------------------------------------
# Финал
# ----------------------------------------------------------
echo ""
echo "========================================="
echo "  НАСТРОЙКА GW-01 ЗАВЕРШЕНА"
echo "========================================="
echo ""
echo "Сетевые интерфейсы:"
ip -br a
echo ""
echo "Таблица маршрутизации:"
ip route
echo ""
echo "Статус iptables:"
systemctl is-active iptables
echo ""
echo "Статус dnsmasq:"
systemctl is-active dnsmasq
echo ""
echo "Статус dhcrelay:"
systemctl is-active dhcrelay
echo ""
echo "Проверка связи с интернетом:"
ping -c 4 8.8.8.8 || echo "ВНИМАНИЕ: Интернет недоступен, проверьте ens18"
