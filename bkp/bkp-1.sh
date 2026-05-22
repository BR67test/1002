#!/bin/bash
# ============================================================
# SRV-BKP-01 — НАСТРОЙКА ХРАНИЛИЩА BORGBACKUP (из APT)
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА ХРАНИЛИЩА SRV-BKP-01"
echo "========================================="

# ----------------------------------------------------------
# 1. Установка BorgBackup
# ----------------------------------------------------------
echo "[1/4] Установка BorgBackup..."
apt-get update
apt-get install -y borg openssh-server

echo ""
echo "Версия BorgBackup:"
borg -V

# ----------------------------------------------------------
# 2. Пользователь
# ----------------------------------------------------------
echo "[2/4] Создание пользователя..."
useradd -m -s /bin/bash borgbackup 2>/dev/null || true
echo "borgbackup:Backup123!" | chpasswd

# ----------------------------------------------------------
# 3. Каталог репозитория
# ----------------------------------------------------------
echo "[3/4] Создание каталога..."
mkdir -p /srv/borg/repo
chown -R borgbackup:borgbackup /srv/borg
chmod 750 /srv/borg

mkdir -p /home/borgbackup/.ssh
chmod 700 /home/borgbackup/.ssh
chown borgbackup:borgbackup /home/borgbackup/.ssh
systemctl enable --now sshd

# ----------------------------------------------------------
# 4. Инициализация репозитория
# ----------------------------------------------------------
echo "[4/4] Инициализация репозитория..."
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
