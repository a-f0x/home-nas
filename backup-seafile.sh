#!/bin/bash
# backup-seafile.sh — Бекап Seafile с использованием переменных из .env
# Гарантирует консистентность БД и файлов

set -e  # Выход при любой ошибке

# =====================================================
# Загрузка переменных окружения
# =====================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_DIR}/.env"

# Проверка существования .env
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Ошибка: Файл .env не найден: $ENV_FILE"
    exit 1
fi

# Загрузка переменных из .env (игнорируя комментарии и пустые строки)
set -a
source "$ENV_FILE"
set +a

# =====================================================
# Настройки (из .env или значения по умолчанию)
# =====================================================
BACKUP_BASE="/mnt/media/volume-b/backup/seafile"
DB_CONTAINER="mariadb"
SEAFILE_CONTAINER="seafile"
RETENTION_DAYS=7  # Хранить последние 7 дней

# Директории
BACKUP_DIR="${BACKUP_BASE}/$(date +%F)"
DB_BACKUP_DIR="${BACKUP_DIR}/db"
DATA_BACKUP_DIR="${BACKUP_DIR}/data"
LOG_FILE="${BACKUP_BASE}/backup.log"

# Пути из .env
SEAFILE_VOLUME_PATH="${SEAFILE_VOLUME:-./volumes/seafile-data}"

# =====================================================
# Функции
# =====================================================
log() {
    echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "❌ ОШИБКА: $1"
    # Пытаемся запустить Seafile обратно перед выходом
    docker compose start "$SEAFILE_CONTAINER" 2>/dev/null || true
    exit 1
}

# =====================================================
# Основной процесс
# =====================================================
log "🚀 Начало бекапа Seafile"
log "📁 Проект: ${PROJECT_DIR}"
log "📁 Seafile volume: ${SEAFILE_VOLUME_PATH}"

# 1. Остановить Seafile
log "🛑 Остановка контейнера $SEAFILE_CONTAINER..."
docker compose stop "$SEAFILE_CONTAINER" || error_exit "Не удалось остановить Seafile"
log "✅ Seafile остановлен"

# 2. Создать директории для бекапа
log "📁 Создание директорий для бекапа..."
mkdir -p "$DB_BACKUP_DIR" "$DATA_BACKUP_DIR" || error_exit "Не удалось создать директории"

# 3. Дамп баз данных
log "🗄️ Дамп баз данных (ccnet_db, seafile_db, seahub_db)..."
docker exec "$DB_CONTAINER" /usr/bin/mariadb-dump \
    -u root -p"${MYSQL_ROOT_PASSWORD}" \
    ccnet_db seafile_db seahub_db | gzip \
    > "${DB_BACKUP_DIR}/seafile-$(date +%F).sql.gz" || error_exit "Не удалось создать дамп БД"

DB_SIZE=$(du -h "${DB_BACKUP_DIR}/seafile-$(date +%F).sql.gz" | cut -f1)
log "✅ Дамп создан: ${DB_SIZE}"

# 4. Бекап файловых данных
log "📁 Копирование файловых данных (rsync)..."
rsync -av --delete \
    "${SEAFILE_VOLUME_PATH}/" \
    "${DATA_BACKUP_DIR}/" || error_exit "Не удалось синхронизировать файлы"

DATA_SIZE=$(du -sh "${DATA_BACKUP_DIR}" | cut -f1)
log "✅ Файлы скопированы: ${DATA_SIZE}"

# 5. Запустить Seafile обратно
log "▶️ Запуск контейнера $SEAFILE_CONTAINER..."
docker compose start "$SEAFILE_CONTAINER" || error_exit "Не удалось запустить Seafile"
log "✅ Seafile запущен"

# 6. Ротация: удалить старые бекапы
log "🗑️ Удаление бекапов старше ${RETENTION_DAYS} дней..."
DELETED_COUNT=$(find "${BACKUP_BASE}" -maxdepth 1 -type d -name "20*" -mtime +${RETENTION_DAYS} | wc -l)
find "${BACKUP_BASE}" -maxdepth 1 -type d -name "20*" -mtime +${RETENTION_DAYS} -exec rm -rf {} \;
log "✅ Удалено старых бекапов: ${DELETED_COUNT}"

# 7. Финал
log "🎉 Бекап завершён успешно!"
log "📍 Путь: ${BACKUP_DIR}"

# Показать сводку
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