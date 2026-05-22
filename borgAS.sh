#!/bin/bash
# ============================================================
# Установка BorgBackup на Astra Linux 1.8
# ============================================================

set -e

echo "========================================="
echo "  УСТАНОВКА BORGBACKUP НА ASTRA LINUX"
echo "========================================="

# 1. Обновление и установка всех зависимостей
echo "[1/3] Установка зависимостей..."
apt-get update
apt-get install -y python3 python3-pip python3-dev python3-setuptools python3-setuptools-scm libssl-dev libacl1-dev liblz4-dev libzstd-dev gcc build-essential pkg-config

# 2. Установка BorgBackup
echo "[2/3] Установка BorgBackup..."
python3 -m pip install --upgrade pip setuptools setuptools-scm
python3 -m pip install borgbackup

# 3. Проверка
echo "[3/3] Проверка..."
borg -V

echo ""
echo "========================================="
echo "  BORGBACKUP УСТАНОВЛЕН"
echo "========================================="
