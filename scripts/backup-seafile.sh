#!/bin/bash
# backup-seafile.sh — Бекап Seafile
set -e

# =====================================================
# Загрузка .env
# =====================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ ! -f "$ENV_FILE" ]; then
    ENV_FILE="./.env"
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Ошибка: Файл .env не найден"
    exit 1
fi

set -a
source "$ENV_FILE"
set +a

# =====================================================
# Настройки
# =====================================================
BACKUP_BASE="/mnt/media/volume-b/backup/seafile"
DB_CONTAINER="mariadb"
SEAFILE_CONTAINER="seafile"
RETENTION_DAYS=7

BACKUP_DIR="${BACKUP_BASE}/$(date +%F)"
DB_BACKUP_DIR="${BACKUP_DIR}/db"
DATA_BACKUP_DIR="${BACKUP_DIR}/data"
LOG_FILE="${BACKUP_BASE}/backup.log"
SEAFILE_VOLUME_PATH="${SEAFILE_VOLUME:-./volumes/seafile-data}"

# =====================================================
# Функции
# =====================================================
log() {
    echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "❌ ОШИБКА: $1"
    docker compose start "$SEAFILE_CONTAINER" 2>/dev/null || true
    exit 1
}

# =====================================================
# Основной процесс
# =====================================================
log "🚀 Начало бекапа Seafile"

# 1. Остановить Seafile
log "🛑 Остановка контейнера $SEAFILE_CONTAINER..."
docker compose stop "$SEAFILE_CONTAINER" || error_exit "Не удалось остановить Seafile"
log "✅ Seafile остановлен"

# 2. Создать директории
log "📁 Создание директорий для бекапа..."
mkdir -p "$DB_BACKUP_DIR" "$DATA_BACKUP_DIR" || error_exit "Не удалось создать директории"

# 3. Дамп баз данных (ИСПРАВЛЕНО: конфиг на хосте → copy в контейнер)
log "🗄️ Дамп баз данных (ccnet_db, seafile_db, seahub_db)..."

# Создаём временный конфиг НА ХОСТЕ
MYSQL_CONFIG_FILE=$(mktemp)
cat > "$MYSQL_CONFIG_FILE" <<EOF
[client]
user=root
password=${MYSQL_ROOT_PASSWORD}
EOF
chmod 600 "$MYSQL_CONFIG_FILE"

# Копируем конфиг В контейнер
docker cp "$MYSQL_CONFIG_FILE" "${DB_CONTAINER}:/tmp/backup.cnf" || error_exit "Не удалось скопировать конфиг в контейнер"

# Делаем дамп с использованием конфига
docker exec "$DB_CONTAINER" /usr/bin/mariadb-dump \
    --defaults-extra-file=/tmp/backup.cnf \
    ccnet_db seafile_db seahub_db | gzip \
    > "${DB_BACKUP_DIR}/seafile-$(date +%F).sql.gz" || error_exit "Не удалось создать дамп БД"

# Чистим конфиг в контейнере и на хосте
docker exec "$DB_CONTAINER" rm -f /tmp/backup.cnf
rm -f "$MYSQL_CONFIG_FILE"

DB_SIZE=$(du -h "${DB_BACKUP_DIR}/seafile-$(date +%F).sql.gz" | cut -f1)
log "✅ Дамп создан: ${DB_SIZE}"

# 4. Бекап файлов
log "📁 Копирование файловых данных (rsync)..."
rsync -av --delete \
    "${SEAFILE_VOLUME_PATH}/" \
    "${DATA_BACKUP_DIR}/" || error_exit "Не удалось синхронизировать файлы"

DATA_SIZE=$(du -sh "${DATA_BACKUP_DIR}" | cut -f1)
log "✅ Файлы скопированы: ${DATA_SIZE}"

# 5. Запустить Seafile
log "▶️ Запуск контейнера $SEAFILE_CONTAINER..."
docker compose start "$SEAFILE_CONTAINER" || error_exit "Не удалось запустить Seafile"
log "✅ Seafile запущен"

# 6. Ротация
log "🗑️ Удаление бекапов старше ${RETENTION_DAYS} дней..."
DELETED_COUNT=$(find "${BACKUP_BASE}" -maxdepth 1 -type d -name "20*" -mtime +${RETENTION_DAYS} | wc -l)
find "${BACKUP_BASE}" -maxdepth 1 -type d -name "20*" -mtime +${RETENTION_DAYS} -exec rm -rf {} \;
log "✅ Удалено старых бекапов: ${DELETED_COUNT}"

# 7. Финал
log "🎉 Бекап завершён успешно!"
log "📍 Путь: ${BACKUP_DIR}"

echo ""
echo "=========================================="
echo "📊 Сводка бекапа"
echo "=========================================="
echo "Дата: $(date +%F)"
echo "БД: ${DB_SIZE}"
echo "Файлы: ${DATA_SIZE}"
echo "Хранение: ${RETENTION_DAYS} дней"
echo "Путь: ${BACKUP_DIR}"
echo "=========================================="