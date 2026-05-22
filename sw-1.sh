#!/bin/bash
# ============================================================
# Скрипт полной настройки коммутатора SW-01 (ЯДРО СЕТИ)
# ОС: ALT Linux 10 (JEOS)
# Порты:
#   ens19 -> GW-01
#   ens20,21 -> Серверный сегмент
#   ens22,23 -> Пользовательский сегмент
# Управление: br0 (бридж) -> 10.0.0.2/24
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА SW-01 (КОММУТАТОР ЯДРА)"
echo "========================================="

# ----------------------------------------------------------
# 1. Обновление и пакеты
# ----------------------------------------------------------
echo "[1/3] Обновление и установка пакетов..."
apt-get update && apt-get dist-upgrade -y
apt-get install -y bridge-utils net-tools openssh-server chrony

# ----------------------------------------------------------
# 2. Очистка старых настроек (на всякий случай)
# ----------------------------------------------------------
echo "[2/3] Очистка старых настроек..."

# Останавливаем OVS если был
systemctl stop openvswitch 2>/dev/null || true
systemctl disable openvswitch 2>/dev/null || true

# Удаляем старые конфиги интерфейсов
rm -rf /etc/net/ifaces/ens19 /etc/net/ifaces/ens20 /etc/net/ifaces/ens21
rm -rf /etc/net/ifaces/ens22 /etc/net/ifaces/ens23 /etc/net/ifaces/br0
rm -f /etc/net/ifaces/default/ipv4route

# ----------------------------------------------------------
# 3. Создание бриджа
# ----------------------------------------------------------
echo "[3/3] Создание бриджа br0..."

# Создаём бридж
ip link add name br0 type bridge
ip link set br0 up

# Добавляем все порты в бридж
for port in ens19 ens20 ens21 ens22 ens23; do
    ip link set $port master br0
    ip link set $port up
done

# Назначаем IP на бридже
ip addr add 10.0.0.2/24 dev br0

# Шлюз
ip route add default via 10.0.0.1

# ----------------------------------------------------------
# Сохранение конфигурации
# ----------------------------------------------------------
mkdir -p /etc/net/ifaces/br0

cat > /etc/net/ifaces/br0/options << 'EOF'
TYPE=bridge
BOOTPROTO=static
ONBOOT=yes
EOF

echo '10.0.0.2/24' > /etc/net/ifaces/br0/ipv4address

# Шлюз
mkdir -p /etc/net/ifaces/default
echo '10.0.0.1' > /etc/net/ifaces/default/ipv4route

# Настройка портов в бридже
for port in ens19 ens20 ens21 ens22 ens23; do
    mkdir -p /etc/net/ifaces/$port
    echo '10.0.0.2/24' > /etc/net/ifaces/$port/ipv4address 2>/dev/null || true
    
    cat > /etc/net/ifaces/$port/options << EOF
TYPE=eth
BOOTPROTO=static
ONBOOT=yes
HOST='br0'
EOF
done

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
echo "Бридж и порты:"
ip -br a | grep -E "ens|br0"
echo ""
echo "Маршруты:"
ip route
echo ""
echo "Пинг GW-01:"
ping -c 4 10.0.0.1
