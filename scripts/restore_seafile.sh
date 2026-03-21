#!/bin/bash
# restore-seafile.sh — Восстановление Seafile из бекапа
# Восстанавливает БД и файлы из выбранной даты

# =====================================================
# Проверка прав root (авто-перезапуск с sudo)
# =====================================================
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  Требуется доступ root. Перезапуск через sudo..."
    exec sudo "$0" "$@"
fi

set -e

# =====================================================
# Загрузка .env (динамический поиск)
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
# Настройки (из .env)
# =====================================================
SEAFILE_BACKUP_DIR="${BACKUP_BASE}/seafile"
DB_CONTAINER="mariadb"
SEAFILE_CONTAINER="seafile"

# =====================================================
# Функции
# =====================================================
log() {
    echo "[$(date '+%F %T')] $1"
}

error_exit() {
    log "❌ ОШИБКА: $1"
    docker compose start "$SEAFILE_CONTAINER" 2>/dev/null || true
    exit 1
}

# Показать доступные бекапы
list_backups() {
    echo ""
    echo "📋 Доступные бекапы:"
    echo "=========================================="
    if [ -d "$SEAFILE_BACKUP_DIR" ]; then
        find "$SEAFILE_BACKUP_DIR" -maxdepth 1 -type d -name "20*" | sort -r | while read -r dir; do
            DATE=$(basename "$dir")
            DB_FILE="$dir/db/seafile-${DATE}.sql.gz"
            DATA_DIR="$dir/data"

            if [ -f "$DB_FILE" ]; then
                DB_SIZE=$(du -h "$DB_FILE" | cut -f1)
            else
                DB_SIZE="❌ нет дампа"
            fi

            if [ -d "$DATA_DIR" ]; then
                DATA_SIZE=$(du -sh "$DATA_DIR" | cut -f1)
            else
                DATA_SIZE="❌ нет данных"
            fi

            echo "  $DATE  |  БД: $DB_SIZE  |  Файлы: $DATA_SIZE"
        done
    else
        echo "  ❌ Директория бекапов не найдена: $SEAFILE_BACKUP_DIR"
    fi
    echo "=========================================="
    echo ""
}

# =====================================================
# Основной процесс
# =====================================================
log "🚀 Восстановление Seafile из бекапа"
log "📁 .env файл: ${ENV_FILE}"
log "📁 Путь бекапов: ${SEAFILE_BACKUP_DIR}"

# Проверка наличия бекапов
if [ ! -d "$SEAFILE_BACKUP_DIR" ]; then
    error_exit "Директория бекапов не найдена: $SEAFILE_BACKUP_DIR"
fi

# Показать доступные бекапы
list_backups

# Получить дату для восстановления (аргумент или интерактивно)
RESTORE_DATE="$1"

if [ -z "$RESTORE_DATE" ]; then
    # Интерактивный выбор
    echo "Введите дату для восстановления (YYYY-MM-DD) или 'q' для выхода:"
    read -r RESTORE_DATE

    if [ "$RESTORE_DATE" = "q" ] || [ -z "$RESTORE_DATE" ]; then
        log "❌ Восстановление отменено"
        exit 0
    fi
fi

# Проверка существования бекапа
BACKUP_DIR="${SEAFILE_BACKUP_DIR}/${RESTORE_DATE}"
DB_BACKUP_FILE="${BACKUP_DIR}/db/seafile-${RESTORE_DATE}.sql.gz"
DATA_BACKUP_DIR="${BACKUP_DIR}/data"

if [ ! -d "$BACKUP_DIR" ]; then
    error_exit "Бекап не найден: $BACKUP_DIR"
fi

if [ ! -f "$DB_BACKUP_FILE" ]; then
    error_exit "Дамп БД не найден: $DB_BACKUP_FILE"
fi

if [ ! -d "$DATA_BACKUP_DIR" ]; then
    error_exit "Данные не найдены: $DATA_BACKUP_DIR"
fi

# Предупреждение
echo ""
echo "⚠️  ВНИМАНИЕ! ⚠️"
echo "=========================================="
echo "Текущие данные Seafile будут ЗАМЕНЕНЫ на бекап от ${RESTORE_DATE}"
echo ""
echo "БД: ${DB_BACKUP_FILE}"
echo "Файлы: ${DATA_BACKUP_DIR}"
echo ""
read -r -p "Продолжить? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log "❌ Восстановление отменено пользователем"
    exit 0
fi

# =====================================================
# Начало восстановления
# =====================================================
log "🛑 Остановка контейнера $SEAFILE_CONTAINER..."
docker compose stop "$SEAFILE_CONTAINER" || error_exit "Не удалось остановить Seafile"
log "✅ Seafile остановлен"

# 1. Восстановление БД
log "🗄️ Восстановление баз данных..."

# Создаём временный конфиг с паролем
MYSQL_CONFIG_FILE=$(mktemp)
cat > "$MYSQL_CONFIG_FILE" <<EOF
[client]
user=root
password=${MYSQL_ROOT_PASSWORD}
EOF
chmod 600 "$MYSQL_CONFIG_FILE"

# Копируем в контейнер
docker cp "$MYSQL_CONFIG_FILE" "${DB_CONTAINER}:/tmp/restore.cnf"

# Восстанавливаем дамп
gunzip -c "$DB_BACKUP_FILE" | docker exec -i "$DB_CONTAINER" /usr/bin/mariadb \
    --defaults-extra-file=/tmp/restore.cnf || error_exit "Не удалось восстановить БД"

# Чистим конфиг
docker exec "$DB_CONTAINER" rm -f /tmp/restore.cnf
rm -f "$MYSQL_CONFIG_FILE"

log "✅ БД восстановлена"

# 2. Восстановление файлов
log "📁 Восстановление файловых данных (rsync)..."

# Очищаем текущие данные перед восстановлением
log "🗑️ Очистка текущих данных..."
rm -rf "${SEAFILE_VOLUME_PATH:?}"/*

# Копируем из бекапа
rsync -av --delete \
    "${DATA_BACKUP_DIR}/" \
    "${SEAFILE_VOLUME_PATH}/" || error_exit "Не удалось восстановить файлы"

log "✅ Файлы восстановлены"

# 3. Запустить Seafile
log "▶️ Запуск контейнера $SEAFILE_CONTAINER..."
docker compose start "$SEAFILE_CONTAINER" || error_exit "Не удалось запустить Seafile"
log "✅ Seafile запущен"

# 4. Проверка
log "⏳ Ожидание запуска Seafile (30 сек)..."
sleep 30

# Проверка, что контейнер работает
if docker compose ps | grep -q "seafile.*Up"; then
    log "✅ Seafile работает"
else
    log "⚠️  Seafile может иметь проблемы. Проверьте логи: docker compose logs seafile"
fi

# 5. Финал
log "🎉 Восстановление завершено успешно!"
log "📍 Дата бекапа: ${RESTORE_DATE}"

echo ""
echo "=========================================="
echo "📊 Сводка восстановления"
echo "=========================================="
echo "Дата бекапа: ${RESTORE_DATE}"
echo "БД: ${DB_BACKUP_FILE}"
echo "Файлы: ${DATA_BACKUP_DIR}"
echo "=========================================="
echo ""
echo "🔗 Доступ к Seafile: https://${SEAFILE_SERVER_HOSTNAME}"
echo "📋 Логи: docker compose logs -f seafile"
echo "=========================================="