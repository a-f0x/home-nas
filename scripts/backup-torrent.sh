#!/bin/bash
# backup-qbittorrent.sh — Бекап qBittorrent (только конфиги, без загрузок)

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
QBITTORRENT_BACKUP_DIR="${BACKUP_BASE}/qbittorrent"
QBITTORRENT_CONTAINER="qbittorrent"
RETENTION_DAYS=7

BACKUP_DIR="${QBITTORRENT_BACKUP_DIR}/$(date +%F)"
CONFIG_BACKUP_DIR="${BACKUP_DIR}/config"
LOG_FILE="${QBITTORRENT_BACKUP_DIR}/backup.log"

# 🔥 Путь к конфигам (с дефолтным значением)
QBITTORRENT_CONFIG_PATH="${QBITTORRENT_CONFIG_PATH:-./volumes/qbittorrent/config}"

# 🔥 Преобразуем в абсолютный путь
PROJECT_DIR="$(dirname "$ENV_FILE")"
if [[ "$QBITTORRENT_CONFIG_PATH" == /* ]]; then
    QBITTORRENT_CONFIG_PATH_ABS="$QBITTORRENT_CONFIG_PATH"
else
    QBITTORRENT_CONFIG_PATH_ABS="$(cd "$PROJECT_DIR" && realpath -m "$QBITTORRENT_CONFIG_PATH")"
fi

# =====================================================
# Функции
# =====================================================
log() {
    echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "❌ ОШИБКА: $1"
    docker compose start "$QBITTORRENT_CONTAINER" 2>/dev/null || true
    exit 1
}

# =====================================================
# Основной процесс
# =====================================================
log "🚀 Начало бекапа qBittorrent"
log "📁 .env файл: ${ENV_FILE}"
log "📁 Путь бекапа: ${QBITTORRENT_BACKUP_DIR}"
log "📁 qBittorrent config: ${QBITTORRENT_CONFIG_PATH_ABS}"

# Проверка, что директория существует
if [ ! -d "$QBITTORRENT_CONFIG_PATH_ABS" ]; then
    error_exit "Директория конфигов не найдена: $QBITTORRENT_CONFIG_PATH_ABS"
fi

# 1. Остановить qBittorrent (для консистентности конфигов)
log "🛑 Остановка контейнера $QBITTORRENT_CONTAINER..."
docker compose stop "$QBITTORRENT_CONTAINER" || error_exit "Не удалось остановить qBittorrent"
log "✅ qBittorrent остановлен"

# 2. Создать директории для бекапа
log "📁 Создание директорий для бекапа..."
mkdir -p "$CONFIG_BACKUP_DIR" || error_exit "Не удалось создать директорию"

# 3. Бекап конфигов
# ❗ Загрузки НЕ бэкапятся (они могут быть скачаны заново)
log "📁 Копирование конфигов..."
rsync -av --delete \
    "${QBITTORRENT_CONFIG_PATH_ABS}/" \
    "${CONFIG_BACKUP_DIR}/" || error_exit "Не удалось скопировать конфиги"

CONFIG_SIZE=$(du -sh "${CONFIG_BACKUP_DIR}" | cut -f1)
log "✅ Конфиги скопированы: ${CONFIG_SIZE}"

# 4. Запустить qBittorrent обратно
log "▶️ Запуск контейнера $QBITTORRENT_CONTAINER..."
docker compose start "$QBITTORRENT_CONTAINER" || error_exit "Не удалось запустить qBittorrent"
log "✅ qBittorrent запущен"

# 5. Ротация: удалить старые бекапы
log "🗑️ Удаление бекапов старше ${RETENTION_DAYS} дней..."
DELETED_COUNT=$(find "${QBITTORRENT_BACKUP_DIR}" -maxdepth 1 -type d -name "20*" -mtime +${RETENTION_DAYS} | wc -l)
find "${QBITTORRENT_BACKUP_DIR}" -maxdepth 1 -type d -name "20*" -mtime +${RETENTION_DAYS} -exec rm -rf {} \;
log "✅ Удалено старых бекапов: ${DELETED_COUNT}"

# 6. Финал
log "🎉 Бекап qBittorrent завершён успешно!"
log "📍 Путь: ${BACKUP_DIR}"

echo ""
echo "=========================================="
echo "📊 Сводка бекапа"
echo "=========================================="
echo "Дата: $(date +%F)"
echo "Конфиги: ${CONFIG_SIZE}"
echo "Хранение: ${RETENTION_DAYS} дней"
echo "Путь: ${BACKUP_DIR}"
echo "📥 Загрузки не бэкапились (можно скачать заново)"
echo "=========================================="