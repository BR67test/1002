#!/bin/bash
# ============================================================
# Скрипт полной настройки SW-01 (OVS, правильный)
# ens19 -> trunk (VLAN 10, 20) к GW-01
# ens20 -> access VLAN 10 (серверы)
# ens21 -> access VLAN 20 (пользователи)
# mgmt  -> IP 10.0.0.2/24 (управление)
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА SW-01 (OVS + VLAN)"
echo "  ens19 -> Trunk (GW-01)"
echo "  ens20 -> Access VLAN 10 (Серверы)"
echo "  ens21 -> Access VLAN 20 (Пользователи)"
echo "  mgmt  -> 10.0.0.2/24"
echo "========================================="

# ----------------------------------------------------------
# 1. Система и пакеты
# ----------------------------------------------------------
echo "[1/4] Обновление и установка пакетов..."
apt-get update && apt-get dist-upgrade -y
apt-get install -y openvswitch net-tools openssh-server chrony

# ----------------------------------------------------------
# 2. Очистка старых конфигов и запуск OVS
# ----------------------------------------------------------
echo "[2/4] Очистка старых настроек и запуск OVS..."

# Останавливаем старые бриджи если есть
ip link del br0 2>/dev/null || true
systemctl stop openvswitch 2>/dev/null || true

# Чистим старые конфиги
rm -rf /etc/net/ifaces/ens19 /etc/net/ifaces/ens20 /etc/net/ifaces/ens21 /etc/net/ifaces/mgmt /etc/net/ifaces/br0 /etc/net/ifaces/default

# Запускаем OVS
systemctl enable --now openvswitch

# Создаём мост
ovs-vsctl --if-exists del-br SW-BR0
ovs-vsctl add-br SW-BR0

# ----------------------------------------------------------
# 3. Настройка портов
# ----------------------------------------------------------
echo "[3/4] Настройка портов..."

# ens19 — trunk (GW-01)
ovs-vsctl add-port SW-BR0 ens19 trunks=10,20

# ens20 — access VLAN 10 (серверы)
ovs-vsctl add-port SW-BR0 ens20 tag=10

# ens21 — access VLAN 20 (пользователи)
ovs-vsctl add-port SW-BR0 ens21 tag=20

# Внутренний интерфейс управления
ovs-vsctl add-port SW-BR0 mgmt -- set Interface mgmt type=internal
ip addr add 10.0.0.2/24 dev mgmt
ip link set mgmt up

# Поднимаем все порты
ip link set ens19 up
ip link set ens20 up
ip link set ens21 up
ip link set SW-BR0 up

# ----------------------------------------------------------
# 4. Сохранение конфигурации и проверка
# ----------------------------------------------------------
echo "[4/4] Сохранение конфигурации..."

# Сохраняем mgmt
mkdir -p /etc/net/ifaces/mgmt
cat > /etc/net/ifaces/mgmt/options << 'EOF'
BOOTPROTO=static
NM_CONTROLLED=no
DISABLED=no
CONFIG_IPV4=yes
ON_BOOT=yes
EOF
echo '10.0.0.2/24' > /etc/net/ifaces/mgmt/ipv4address

# Шлюз
mkdir -p /etc/net/ifaces/default
echo '10.0.0.1' > /etc/net/ifaces/default/ipv4route

# Синхронизация времени
systemctl enable --now chronyd

# ----------------------------------------------------------
# Финал
# ----------------------------------------------------------
echo ""
echo "========================================="
echo "  НАСТРОЙКА SW-01 ЗАВЕРШЕНА"
echo "========================================="
echo ""
echo "Конфигурация OVS:"
ovs-vsctl show
echo ""
echo "Интерфейсы:"
ip -br a | grep -E "ens19|ens20|ens21|mgmt|SW-BR0"
echo ""
echo "Маршруты:"
ip route
echo ""
echo "Пинг GW-01:"
ping -c 4 10.0.0.1
