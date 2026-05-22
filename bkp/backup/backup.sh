#!/bin/bash
# ============================================================
# Сценарий автоматического резервного копирования (backup.sh)
# Размещается на рабочих станциях в /usr/local/bin/
# ============================================================

# Конфигурация
REPO="borgbackup@10.0.10.11:/srv/borg/repo"
LOG_FILE="/var/log/backup.log"
HOSTNAME=$(hostname)
LOCK_FILE="/var/run/backup.lock"

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Проверка доступности Backup-сервера
if ! ping -c 2 -W 5 10.0.10.11 > /dev/null 2>&1; then
    log "ОШИБКА: Сервер резервного копирования недоступен"
    exit 1
fi

# Блокировка повторного запуска
if [ -f "$LOCK_FILE" ]; then
    log "ОШИБКА: Предыдущий процесс ещё выполняется"
    exit 1
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# Экспорт парольной фразы
export BORG_PASSPHRASE='ваша_парольная_фраза'

# Выполнение резервного копирования
log "ЗАПУСК: Начало резервного копирования"

borg create \
    --verbose \
    --filter AME \
    --list \
    --stats \
    --compression zstd \
    --exclude-caches \
    --exclude '*.tmp' \
    --exclude '*.pyc' \
    --exclude '.cache' \
    --exclude 'Trash' \
    --exclude 'Downloads' \
    "$REPO::${HOSTNAME}-{now:%Y-%m-%d_%H:%M:%S}" \
    /home \
    2>&1 | tee -a "$LOG_FILE"

BACKUP_EXIT_CODE=${PIPESTATUS[0]}

# Ротация старых копий при успехе
if [ $BACKUP_EXIT_CODE -eq 0 ]; then
    log "УСПЕХ: Резервное копирование завершено"
    
    borg prune \
        --verbose \
        --list \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 3 \
        "$REPO" \
        --prefix "${HOSTNAME}-" \
        2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        log "УСПЕХ: Ротация завершена"
    else
        log "ОШИБКА: Ротация не выполнена"
    fi
else
    log "ОШИБКА: Копирование завершилось с кодом $BACKUP_EXIT_CODE"
fi

unset BORG_PASSPHRASE
log "ЗАВЕРШЕНИЕ: Сценарий выполнен"
