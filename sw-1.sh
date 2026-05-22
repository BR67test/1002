#!/bin/bash
# ============================================================
# Скрипт настройки коммутатора SW-01 (ЯДРО СЕТИ)
# ОС: ALT Linux 10 (JEOS)
# ens19 -> GW-01 (управление, IP: 10.0.0.2/24)
# ens20 -> Серверный сегмент (trunk через OVS)
# ens21 -> Пользовательский сегмент (trunk через OVS)
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА SW-01 (КОММУТАТОР ЯДРА)"
echo "========================================="

# ----------------------------------------------------------
# 1. Система и пакеты
# ----------------------------------------------------------
echo "[1/4] Обновление и установка пакетов..."
apt-get update && apt-get dist-upgrade -y
apt-get install -y openvswitch net-tools openssh-server chrony

# ----------------------------------------------------------
# 2. Настройка ens19 (управление)
# ----------------------------------------------------------
echo "[2/4] Настройка управления (ens19)..."
mkdir -p /etc/net/ifaces/ens19

cat > /etc/net/ifaces/ens19/options << 'EOF'
TYPE=eth
BOOTPROTO=static
ONBOOT=yes
EOF

echo '10.0.0.2/24' > /etc/net/ifaces/ens19/ipv4address

# Шлюз
mkdir -p /etc/net/ifaces/default
echo '10.0.0.1' > /etc/net/ifaces/default/ipv4route

systemctl restart network

# Проверяем, что сеть поднялась
echo ""
echo "=== После настройки ens19 ==="
ip -br a | grep ens19
ping -c 2 10.0.0.1 && echo "GW-01 доступен!" || echo "GW-01 НЕ доступен"
echo ""

# ----------------------------------------------------------
# 3. Open vSwitch для ens20 и ens21
# ----------------------------------------------------------
echo "[3/4] Настройка OVS..."
systemctl enable --now openvswitch

ovs-vsctl add-br SW-BR0
ovs-vsctl add-port SW-BR0 ens20 trunks=10,20
ovs-vsctl add-port SW-BR0 ens21 trunks=10,20

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
echo "ens19 (управление):"
ip -br a | grep ens19
echo ""
echo "Таблица маршрутизации:"
ip route
echo ""
echo "Конфигурация OVS:"
ovs-vsctl show
echo ""
echo "Проверка GW-01:"
ping -c 4 10.0.0.1
