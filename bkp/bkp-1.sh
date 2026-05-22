#!/bin/bash
# ============================================================
# SRV-BKP-01 — НАСТРОЙКА ХРАНИЛИЩА BORGBACKUP
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА ХРАНИЛИЩА SRV-BKP-01"
echo "========================================="

# ----------------------------------------------------------
# 1. Установка пакетов
# ----------------------------------------------------------
echo "[1/5] Установка пакетов..."
apt-get update
apt-get install -y python3 openssh-server gcc python3-dev libacl-devel openssl-devel lz4-devel zstd-devel libb2-devel wget

# Установка pip (если нет в репозитории)
if ! command -v pip3 &> /dev/null; then
    apt-get install -y python3-module-pip 2>/dev/null || {
        wget -q https://bootstrap.pypa.io/get-pip.py
        python3 get-pip.py
    }
fi

# ----------------------------------------------------------
# 2. Установка BorgBackup
# ----------------------------------------------------------
echo "[2/5] Установка BorgBackup..."
pip3 install borgbackup

# ----------------------------------------------------------
# 3. Пользователь
# ----------------------------------------------------------
echo "[3/5] Создание пользователя borgbackup..."
useradd -m -s /bin/bash borgbackup 2>/dev/null || true
echo "borgbackup:Backup123!" | chpasswd

# ----------------------------------------------------------
# 4. Каталог репозитория
# ----------------------------------------------------------
echo "[4/5] Создание каталога..."
mkdir -p /srv/borg/repo
chown -R borgbackup:borgbackup /srv/borg
chmod 750 /srv/borg

mkdir -p /home/borgbackup/.ssh
chmod 700 /home/borgbackup/.ssh
chown borgbackup:borgbackup /home/borgbackup/.ssh
systemctl enable --now sshd

# ----------------------------------------------------------
# 5. Инициализация репозитория
# ----------------------------------------------------------
echo "[5/5] Инициализация репозитория..."
borg init --encryption=repokey-blake2 /srv/borg/repo
borg key export /srv/borg/repo /root/borg-repokey.txt
chmod 600 /root/borg-repokey.txt

echo ""
echo "========================================="
echo "  ХРАНИЛИЩЕ SRV-BKP-01 ГОТОВО"
echo "========================================="
echo ""
echo "Репозиторий: /srv/borg/repo"
echo "Ключ: /root/borg-repokey.txt"
