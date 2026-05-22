#!/bin/bash
# ============================================================
# SRV-BKP-01 — НАСТРОЙКА ХРАНИЛИЩА BORGBACKUP
# ============================================================

set -e

echo "========================================="
echo "  НАСТРОЙКА ХРАНИЛИЩА SRV-BKP-01"
echo "========================================="

# ----------------------------------------------------------
# 1. Установка зависимостей
# ----------------------------------------------------------
echo "[1/5] Установка зависимостей..."
apt-get update
apt-get install -y python3-module-pkgconfig python3-module-setuptools \
    python3-module-wheel python3-module-msgpack libssl-devel python3-dev \
    libacl-devel libacl liblz4-devel libzstd-devel libxxhash-devel \
    openssh-server python3-module-pip

# ----------------------------------------------------------
# 2. Установка BorgBackup
# ----------------------------------------------------------
echo "[2/5] Установка BorgBackup..."

# Если pip3 не установился — через ensurepip
if ! command -v pip3 &> /dev/null; then
    python3 -m ensurepip --upgrade
fi

python3 -m pip install borgbackup

echo ""
echo "Версия BorgBackup:"
borg -V

# ----------------------------------------------------------
# 3. Пользователь
# ----------------------------------------------------------
echo "[3/5] Создание пользователя..."
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
