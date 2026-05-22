#!/bin/bash
# ============================================================
# GW-01 — МАРШРУТИЗАТОР
# ens18 -> WAN (DHCP)
# ens19 -> LAN (trunk, 10.0.0.1/24)
# ============================================================

set -e

echo "=== НАСТРОЙКА GW-01 ==="

# 1. Пакеты
apt-get update && apt-get dist-upgrade -y
apt-get install -y iptables net-tools openssh-server chrony vlan

# 2. ens19 (trunk, native IP для управления)
mkdir -p /etc/net/ifaces/ens19
cat > /etc/net/ifaces/ens19/options << 'EOF'
TYPE=eth
BOOTPROTO=static
ONBOOT=yes
EOF
echo '10.0.0.1/24' > /etc/net/ifaces/ens19/ipv4address

# 3. Форвардинг
echo 1 > /proc/sys/net/ipv4/ip_forward
grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf || echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

# 4. NAT + фаервол
cat > /etc/iptables.sh << 'EOF'
#!/bin/bash
iptables -F
iptables -t nat -F
iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE
EOF
chmod +x /etc/iptables.sh
/etc/iptables.sh

# 5. Автозапуск
cat > /etc/systemd/system/iptables.service << 'EOF'
[Unit]
Description=IPTables
After=network.target
[Service]
Type=oneshot
ExecStart=/etc/iptables.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl enable iptables.service

systemctl enable --now chronyd
systemctl restart network

echo ""
echo "=== ГОТОВО: GW-01 ==="
ip -br a
ping -c 2 8.8.8.8
