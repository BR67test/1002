# Создать пользователя
useradd -m -s /bin/bash borgbackup 2>/dev/null || true
echo "borgbackup:Backup123!" | chpasswd

# Создать каталог и права
mkdir -p /srv/borg/repo
chown -R borgbackup:borgbackup /srv/borg
chmod -R 750 /srv/borg

# Настроить SSH
mkdir -p /home/borgbackup/.ssh
chmod 700 /home/borgbackup/.ssh
chown borgbackup:borgbackup /home/borgbackup/.ssh
