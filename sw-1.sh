#!/bin/bash
# ============================================================
# Скрипт полной настройки коммутатора SW-01 (ЯДРО СЕТИ)
# ОС: ALT Linux 10 (JEOS)
# Порты:
#   ens19 -> GW-01 (trunk, VLAN 10, 20)
#   ens20 -> SW-SRV серверный сегмент (trunk, VLAN 10, 20)
#   ens21 -> SW-SRV серверный сегмент (trunk, дубль)
#   ens22 -> SW-USR пользовательский сегмент (trunk, VLAN 10, 20)
#   ens23 -> SW-USR пользовательский сегмент (trunk, дубль)
# Управление: ens19 имеет IP 10.0.0.2/24 (как в прошлый раз)
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА SW-01 (КОММУТАТОР ЯДРА)"
echo "  ens19 -> GW-01 (управление + транк)"
echo "  ens20,21 -> Серверный сегмент"
echo "  ens22,23 -> Пользовательский сегмент"
echo "========================================="

# ----------------------------------------------------------
# 1. Обновление системы и установка пакетов
# ----------------------------------------------------------
echo "[1/3] Обновление и установка пакетов..."
apt-get update && apt-get dist-upgrade -y
apt-get install -y openvswitch net-tools openssh-server chrony

# ----------------------------------------------------------
# 2. Настройка ens19 (управление + транзит)
# ----------------------------------------------------------
echo "[2/3] Настройка ens19 (IP: 10.0.0.2/24)..."

mkdir -p /etc/net/ifaces/ens19

cat > /etc/net/ifaces/ens19/options << 'EOF'
TYPE=eth
BOOTPROTO=static
ONBOOT=yes
EOF

echo '10.0.0.2/24' > /etc/net/ifaces/ens19/ipv4address

# Шлюз по умолчанию
mkdir -p /etc/net/ifaces/default
echo '10.0.0.1' > /etc/net/ifaces/default/ipv4route

systemctl restart network

# Проверка связи
echo ""
echo "=== Проверка связи с GW-01 ==="
ping -c 2 10.0.0.1 && echo "GW-01 доступен" || echo "GW-01 НЕ доступен"

# ----------------------------------------------------------
# 3. Open vSwitch для остальных портов
# ----------------------------------------------------------
echo ""
echo "[3/3] Настройка OVS..."
systemctl enable --now openvswitch

# Создаём мост
ovs-vsctl add-br SW-BR0

# Добавляем все порты как trunk
ovs-vsctl add-port SW-BR0 ens19 trunks=10,20   # GW-01
ovs-vsctl add-port SW-BR0 ens20 trunks=10,20   # Серверный (основной)
ovs-vsctl add-port SW-BR0 ens21 trunks=10,20   # Серверный (дубль)
ovs-vsctl add-port SW-BR0 ens22 trunks=10,20   # Пользовательский (основной)
ovs-vsctl add-port SW-BR0 ens23 trunks=10,20   # Пользовательский (дубль)

# Поднимаем интерфейсы
for port in ens20 ens21 ens22 ens23 SW-BR0; do
    ip link set $port up
done

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
echo "Маршруты:"
ip route
echo ""
echo "Конфигурация OVS:"
ovs-vsctl show
echo ""
echo "Пинг GW-01:"
ping -c 4 10.0.0.1
