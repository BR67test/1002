#!/bin/bash
# ============================================================
# SW-01 — КОММУТАТОР (OVS + VLAN)
# ens19 -> GW-01 (trunk)
# ens20 -> Серверы (access VLAN 10)
# ens21 -> Пользователи (access VLAN 20)
# mgmt  -> IP 10.0.0.2/24
# ============================================================

set -e

echo "=== НАСТРОЙКА SW-01 ==="

# 1. Пакеты
apt-get update && apt-get dist-upgrade -y
apt-get install -y openvswitch net-tools openssh-server chrony

# 2. OVS
systemctl enable --now openvswitch
ovs-vsctl --if-exists del-br SW-BR0
ovs-vsctl add-br SW-BR0

# Порты
ovs-vsctl add-port SW-BR0 ens19            # trunk (native VLAN 1 для управления)
ovs-vsctl add-port SW-BR0 ens20 tag=10     # access VLAN 10 (серверы)
ovs-vsctl add-port SW-BR0 ens21 tag=20     # access VLAN 20 (пользователи)

# Управление
ovs-vsctl add-port SW-BR0 mgmt -- set Interface mgmt type=internal
ip addr add 10.0.0.2/24 dev mgmt
ip link set mgmt up
ip route add default via 10.0.0.1

# Поднять порты
for p in ens19 ens20 ens21 SW-BR0; do
    ip link set $p up
done

# 3. Сохранение конфигурации управления
mkdir -p /etc/net/ifaces/mgmt /etc/net/ifaces/default

cat > /etc/net/ifaces/mgmt/options << 'EOF'
BOOTPROTO=static
NM_CONTROLLED=no
DISABLED=no
CONFIG_IPV4=yes
ON_BOOT=yes
EOF
echo '10.0.0.2/24' > /etc/net/ifaces/mgmt/ipv4address
echo '10.0.0.1' > /etc/net/ifaces/default/ipv4route

systemctl enable --now chronyd

echo ""
echo "=== ГОТОВО: SW-01 ==="
ovs-vsctl show
echo ""
ip -br a | grep -E "ens|mgmt"
echo ""
ping -c 4 10.0.0.1
