#!/bin/bash
# ============================================================
# GW-01 — МАРШРУТИЗАТОР (3 порта)
# ens18 -> WAN (DHCP)
# ens19 -> Серверный сегмент (10.0.10.1/24)
# ens20 -> Пользовательский сегмент (10.0.20.1/24)
# ============================================================

set -e

echo "=== НАСТРОЙКА GW-01 (3 порта) ==="

# ----------------------------------------------------------
# 1. Обновление и пакеты
# ----------------------------------------------------------
echo "[1/5] Обновление и пакеты..."
apt-get update && apt-get dist-upgrade -y
apt-get install -y iptables net-tools openssh-server chrony

# ----------------------------------------------------------
# 2. Настройка ens19 (серверы)
# ----------------------------------------------------------
echo "[2/5] Настройка ens19 (серверы)..."
mkdir -p /etc/net/ifaces/ens19

cat > /etc/net/ifaces/ens19/options << 'EOF'
TYPE=eth
BOOTPROTO=static
ONBOOT=yes
EOF
echo '10.0.10.1/24' > /etc/net/ifaces/ens19/ipv4address

# ----------------------------------------------------------
# 3. Настройка ens20 (пользователи)
# ----------------------------------------------------------
echo "[3/5] Настройка ens20 (пользователи)..."
mkdir -p /etc/net/ifaces/ens20

cat > /etc/net/ifaces/ens20/options << 'EOF'
TYPE=eth
BOOTPROTO=static
ONBOOT=yes
EOF
echo '10.0.20.1/24' > /etc/net/ifaces/ens20/ipv4address

systemctl restart network

# ----------------------------------------------------------
# 4. Форвардинг
# ----------------------------------------------------------
echo "[4/5] Форвардинг..."
echo 1 > /proc/sys/net/ipv4/ip_forward
grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf || echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

# ----------------------------------------------------------
# 5. NAT и фаервол
# ----------------------------------------------------------
echo "[5/5] NAT и фаервол..."

cat > /etc/iptables.sh << 'EOF'
#!/bin/bash
iptables -F
iptables -t nat -F
iptables -P FORWARD ACCEPT

# NAT для обоих сегментов
iptables -t nat -A POSTROUTING -s 10.0.10.0/24 -o ens18 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.0.20.0/24 -o ens18 -j MASQUERADE
EOF

chmod +x /etc/iptables.sh
/etc/iptables.sh

# Сохранение
iptables-save > /etc/sysconfig/iptables

cat > /etc/systemd/system/iptables.service << 'EOF'
[Unit]
Description=IPTables
After=network.target
[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/sysconfig/iptables
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF

systemctl enable iptables.service
systemctl enable --now chronyd

echo ""
echo "=== ГОТОВО: GW-01 ==="
ip -br a
echo ""
echo "Пинг интернета:"
ping -c 2 8.8.8.8 && echo "Интернет есть" || echo "Интернета нет"
