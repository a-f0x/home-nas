#!/bin/bash
# backup-navidrome.sh — Бекап Navidrome (только БД + конфиги, без музыки)

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
NAVIDROME_BACKUP_DIR="${BACKUP_BASE}/navidrome"
NAVIDROME_CONTAINER="navidrome"
RETENTION_DAYS=7

BACKUP_DIR="${NAVIDROME_BACKUP_DIR}/$(date +%F)"
DATA_BACKUP_DIR="${BACKUP_DIR}/data"
LOG_FILE="${NAVIDROME_BACKUP_DIR}/backup.log"

# 🔥 Путь к данным (с дефолтным значением)
NAVIDROME_DATA_PATH="${NAVIDROME_DATA_PATH:-./volumes/navidrome/data}"

# 🔥 Преобразуем в абсолютный путь
PROJECT_DIR="$(dirname "$ENV_FILE")"
if [[ "$NAVIDROME_DATA_PATH" == /* ]]; then
    NAVIDROME_DATA_PATH_ABS="$NAVIDROME_DATA_PATH"
else
    NAVIDROME_DATA_PATH_ABS="$(cd "$PROJECT_DIR" && realpath -m "$NAVIDROME_DATA_PATH")"
fi

# =====================================================
# Функции
# =====================================================
log() {
    echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "❌ ОШИБКА: $1"
    docker compose start "$NAVIDROME_CONTAINER" 2>/dev/null || true
    exit 1
}

# =====================================================
# Основной процесс
# =====================================================
log "🚀 Начало бекапа Navidrome"
log "📁 .env файл: ${ENV_FILE}"
log "📁 Путь бекапа: ${NAVIDROME_BACKUP_DIR}"
log "📁 Navidrome data: ${NAVIDROME_DATA_PATH_ABS}"

# Проверка, что директория существует
if [ ! -d "$NAVIDROME_DATA_PATH_ABS" ]; then
    error_exit "Директория данных не найдена: $NAVIDROME_DATA_PATH_ABS"
fi

# 1. Остановить Navidrome
log "🛑 Остановка контейнера $NAVIDROME_CONTAINER..."
docker compose stop "$NAVIDROME_CONTAINER" || error_exit "Не удалось остановить Navidrome"
log "✅ Navidrome остановлен"

# 2. Создать директории для бекапа
log "📁 Создание директорий для бекапа..."
mkdir -p "$DATA_BACKUP_DIR" || error_exit "Не удалось создать директорию"

# 3. Бекап данных
log "📁 Копирование данных (БД + конфиги)..."
rsync -av --delete \
    "${NAVIDROME_DATA_PATH_ABS}/" \
    "${DATA_BACKUP_DIR}/" || error_exit "Не удалось скопировать данные"

DATA_SIZE=$(du -sh "${DATA_BACKUP_DIR}" | cut -f1)
log "✅ Данные скопированы: ${DATA_SIZE}"

# 4. Запустить Navidrome обратно
log "▶️ Запуск контейнера $NAVIDROME_CONTAINER..."
docker compose start "$NAVIDROME_CONTAINER" || error_exit "Не удалось запустить Navidrome"
log "✅ Navidrome запущен"

# 5. Ротация
log "🗑️ Удаление бекапов старше ${RETENTION_DAYS} дней..."
DELETED_COUNT=$(find "${NAVIDROME_BACKUP_DIR}" -maxdepth 1 -type d -name "20*" -mtime +${RETENTION_DAYS} | wc -l)
find "${NAVIDROME_BACKUP_DIR}" -maxdepth 1 -type d -name "20*" -mtime +${RETENTION_DAYS} -exec rm -rf {} \;
log "✅ Удалено старых бекапов: ${DELETED_COUNT}"

# 6. Финал
log "🎉 Бекап Navidrome завершён успешно!"
log "📍 Путь: ${BACKUP_DIR}"

echo ""
echo "=========================================="
echo "📊 Сводка бекапа"
echo "=========================================="
echo "Дата: $(date +%F)"
echo "Данные: ${DATA_SIZE}"
echo "Хранение: ${RETENTION_DAYS} дней"
echo "Путь: ${BACKUP_DIR}"
echo "🎵 Музыка не бэкапилась (монтируется отдельно)"
echo "=========================================="