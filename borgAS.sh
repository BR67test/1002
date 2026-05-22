#!/bin/bash
# ============================================================
# Установка BorgBackup на Astra Linux 1.8
# ============================================================

set -e

echo "========================================="
echo "  УСТАНОВКА BORGBACKUP НА ASTRA LINUX"
echo "========================================="

# 1. Обновление
echo "[1/3] Обновление репозиториев..."
apt-get update

# 2. Установка
echo "[2/3] Установка BorgBackup..."
if apt-get install -y borgbackup 2>/dev/null; then
    echo "Установлен из пакета borgbackup"
elif apt-get install -y borg 2>/dev/null; then
    echo "Установлен из пакета borg"
else
    echo "Установка через pip..."
    apt-get install -y python3 python3-pip python3-dev libssl-dev libacl1-dev liblz4-dev libzstd-dev gcc build-essential pkg-config
    pip3 install borgbackup
fi

# 3. Проверка
echo "[3/3] Проверка..."
borg -V

echo ""
echo "========================================="
echo "  BORGBACKUP УСТАНОВЛЕН"
echo "========================================="
