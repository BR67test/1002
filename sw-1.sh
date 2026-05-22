#!/bin/bash
# ============================================================
# Скрипт полной настройки коммутатора SW-01 (ЯДРО СЕТИ)
# ОС: ALT Linux 10 (JEOS)
# Порты:
#   ens19 -> GW-01 (управление + VLAN trunk)
#   ens20 -> Серверный сегмент (access VLAN 10)
#   ens21 -> Пользовательский сегмент (access VLAN 20)
# Управление: IP на ens19 -> 10.0.0.2/24
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА SW-01 (3 порта)"
echo "  ens19 -> GW-01"
echo "  ens20 -> Серверы (access VLAN 10)"
echo "  ens21 -> Пользователи (access VLAN 20)"
echo "========================================="

# ----------------------------------------------------------
# 1. Обновление и пакеты
# ----------------------------------------------------------
echo "[1/4] Обновление и установка пакетов..."
apt-get update && apt-get dist-upgrade -y
apt-get install -y openvswitch net-tools openssh-server chrony

# ----------------------------------------------------------
# 2. Настройка ens19 (управление)
# ----------------------------------------------------------
echo "[2/4] Настройка ens19 (IP: 10.0.0.2/24)..."

mkdir -p /etc/net/ifaces/ens19

cat > /etc/net/ifaces/ens19/options << 'EOF'
TYPE=eth
BOOTPROTO=static
ONBOOT=yes
EOF

echo '10.0.0.2/24' > /etc/net/ifaces/ens19/ipv4address

mkdir -p /etc/net/ifaces/default
echo '10.0.0.1' > /etc/net/ifaces/default/ipv4route

systemctl restart network

echo ""
echo "=== Проверка связи с GW-01 ==="
ping -c 2 10.0.0.1 && echo "GW-01 доступен" || echo "GW-01 НЕ доступен"

# ----------------------------------------------------------
# 3. Open vSwitch для VLAN
# ----------------------------------------------------------
echo ""
echo "[3/4] Настройка OVS..."

systemctl enable --now openvswitch

ovs-vsctl add-br SW-BR0

# ens19 как trunk (пропускает оба VLAN)
ovs-vsctl add-port SW-BR0 ens19 trunks=10,20

# ens20 — access в VLAN 10 (серверы)
ovs-vsctl add-port SW-BR0 ens20 tag=10

# ens21 — access в VLAN 20 (пользователи)
ovs-vsctl add-port SW-BR0 ens21 tag=20

# Поднимаем порты
ip link set ens20 up
ip link set ens21 up
ip link set SW-BR0 up

# ----------------------------------------------------------
# 4. Синхронизация времени
# ----------------------------------------------------------
echo "[4/4] Настройка chrony..."
systemctl enable --now chronyd

# ----------------------------------------------------------
# Финал
# ----------------------------------------------------------
echo ""
echo "========================================="
echo "  НАСТРОЙКА SW-01 ЗАВЕРШЕНА"
echo "========================================="
echo ""
echo "ens19 (управление + trunk):"
ip -br a | grep ens19
echo ""
echo "Конфигурация OVS:"
ovs-vsctl show
echo ""
echo "Маршруты:"
ip route
echo ""
echo "Пинг GW-01:"
ping -c 4 10.0.0.1
