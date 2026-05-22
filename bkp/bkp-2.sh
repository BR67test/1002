#!/bin/bash
# ============================================================
# SRV-BKP-02 — НАСТРОЙКА РЕЗЕРВНОГО ХРАНИЛИЩА
# IP: 10.0.10.12
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА ХРАНИЛИЩА SRV-BKP-02"
echo "========================================="

# ----------------------------------------------------------
# 1. Установка BorgBackup
# ----------------------------------------------------------
echo "[1/4] Установка BorgBackup..."
apt-get update
apt-get install -y borgbackup openssh-server

# ----------------------------------------------------------
# 2. Создание пользователя borgbackup
# ----------------------------------------------------------
echo "[2/4] Создание пользователя borgbackup..."
useradd -m -s /bin/bash borgbackup
echo "borgbackup:Backup123!" | chpasswd

# ----------------------------------------------------------
# 3. Создание каталога репозитория
# ----------------------------------------------------------
echo "[3/4] Создание каталога репозитория..."
mkdir -p /srv/borg/repo
chown -R borgbackup:borgbackup /srv/borg
chmod 750 /srv/borg

# ----------------------------------------------------------
# 4. Настройка SSH и инициализация
# ----------------------------------------------------------
echo "[4/4] Настройка SSH..."
mkdir -p /home/borgbackup/.ssh
chmod 700 /home/borgbackup/.ssh
chown borgbackup:borgbackup /home/borgbackup/.ssh

systemctl enable --now sshd

# Инициализация репозитория
borg init --encryption=repokey-blake2 /srv/borg/repo
borg key export /srv/borg/repo /root/borg-repokey.txt
chmod 600 /root/borg-repokey.txt

echo ""
echo "========================================="
echo "  ХРАНИЛИЩЕ SRV-BKP-02 ГОТОВО"
echo "========================================="
echo ""
echo "Репозиторий: /srv/borg/repo"
echo "Пользователь: borgbackup (Backup123!)"
echo "Ключ: /root/borg-repokey.txt"
