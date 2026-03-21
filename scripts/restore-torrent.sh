#!/bin/bash
# restore-qbittorrent.sh — Восстановление qBittorrent из бекапа

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
QBITTORRENT_CONTAINER="torrent"

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
    echo "[$(date '+%F %T')] $1"
}

error_exit() {
    log "❌ ОШИБКА: $1"
    docker compose start "$QBITTORRENT_CONTAINER" 2>/dev/null || true
    exit 1
}

list_backups() {
    echo ""
    echo "📋 Доступные бекапы:"
    echo "=========================================="
    if [ -d "$QBITTORRENT_BACKUP_DIR" ]; then
        find "$QBITTORRENT_BACKUP_DIR" -maxdepth 1 -type d -name "20*" | sort -r | while read -r dir; do
            DATE=$(basename "$dir")
            CONFIG_DIR="$dir/config"

            if [ -d "$CONFIG_DIR" ]; then
                CONFIG_SIZE=$(du -sh "$CONFIG_DIR" | cut -f1)
                # 🔥 Правильный путь к конфигу
                CONF_FILE="$CONFIG_DIR/qBittorrent/config/qBittorrent.conf"
                if [ -f "$CONF_FILE" ]; then
                    echo "  $DATE  |  Конфиг: ✅  |  Всего: $CONFIG_SIZE"
                else
                    echo "  $DATE  |  ❌ нет qBittorrent.conf  |  Всего: $CONFIG_SIZE"
                fi
            else
                echo "  $DATE  |  ❌ нет конфигов"
            fi
        done
    else
        echo "  ❌ Директория бекапов не найдена: $QBITTORRENT_BACKUP_DIR"
    fi
    echo "=========================================="
    echo ""
}

# =====================================================
# Основной процесс
# =====================================================
log "🚀 Восстановление qBittorrent из бекапа"
log "📁 .env файл: ${ENV_FILE}"
log "📁 Путь бекапов: ${QBITTORRENT_BACKUP_DIR}"
log "📁 qBittorrent config: ${QBITTORRENT_CONFIG_PATH_ABS}"

# Проверка наличия бекапов
if [ ! -d "$QBITTORRENT_BACKUP_DIR" ]; then
    error_exit "Директория бекапов не найдена: $QBITTORRENT_BACKUP_DIR"
fi

list_backups

RESTORE_DATE="$1"

if [ -z "$RESTORE_DATE" ]; then
    echo "Введите дату для восстановления (YYYY-MM-DD) или 'q' для выхода:"
    read -r RESTORE_DATE

    if [ "$RESTORE_DATE" = "q" ] || [ -z "$RESTORE_DATE" ]; then
        log "❌ Восстановление отменено"
        exit 0
    fi
fi

BACKUP_DIR="${QBITTORRENT_BACKUP_DIR}/${RESTORE_DATE}"
CONFIG_BACKUP_DIR="${BACKUP_DIR}/config"

if [ ! -d "$BACKUP_DIR" ]; then
    error_exit "Бекап не найден: $BACKUP_DIR"
fi

if [ ! -d "$CONFIG_BACKUP_DIR" ]; then
    error_exit "Конфиги не найдены: $CONFIG_BACKUP_DIR"
fi

# 🔥 Проверка конфига по правильному пути
CONF_FILE="$CONFIG_BACKUP_DIR/qBittorrent/config/qBittorrent.conf"
if [ ! -f "$CONF_FILE" ]; then
    error_exit "Файл qBittorrent.conf не найден: $CONF_FILE"
fi

echo ""
echo "⚠️  ВНИМАНИЕ! ⚠️"
echo "=========================================="
echo "Текущие конфиги qBittorrent будут ЗАМЕНЕНЫ на бекап от ${RESTORE_DATE}"
echo ""
echo "Источник: ${CONFIG_BACKUP_DIR}"
echo "Назначение: ${QBITTORRENT_CONFIG_PATH_ABS}"
echo ""
echo "📥 Загрузки НЕ будут затронуты (останутся на месте)"
echo ""
read -r -p "Продолжить? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log "❌ Восстановление отменено пользователем"
    exit 0
fi

# =====================================================
# Начало восстановления
# =====================================================
log "🛑 Остановка контейнера $QBITTORRENT_CONTAINER..."
docker compose stop "$QBITTORRENT_CONTAINER" || error_exit "Не удалось остановить qBittorrent"
log "✅ qBittorrent остановлен"

log "📁 Восстановление конфигов (rsync)..."
log "🗑️ Очистка текущих конфигов..."

rm -rf "${QBITTORRENT_CONFIG_PATH_ABS:?}"/*

rsync -av --delete \
    "${CONFIG_BACKUP_DIR}/" \
    "${QBITTORRENT_CONFIG_PATH_ABS}/" || error_exit "Не удалось восстановить конфиги"

log "✅ Конфиги восстановлены"

log "🔐 Проверка прав доступа..."
chown -R 1000:1000 "${QBITTORRENT_CONFIG_PATH_ABS}" 2>/dev/null || true
log "✅ Права проверены"

log "▶️ Запуск контейнера $QBITTORRENT_CONTAINER..."
docker compose start "$QBITTORRENT_CONTAINER" || error_exit "Не удалось запустить qBittorrent"
log "✅ qBittorrent запущен"

log "⏳ Ожидание запуска qBittorrent (15 сек)..."
sleep 15

if docker compose ps | grep -q "torrent.*Up"; then
    log "✅ qBittorrent работает"
else
    log "⚠️  qBittorrent может иметь проблемы. Проверьте логи: docker compose logs torrent"
fi

log "🎉 Восстановление завершено успешно!"
log "📍 Дата бекапа: ${RESTORE_DATE}"

echo ""
echo "=========================================="
echo "📊 Сводка восстановления"
echo "=========================================="
echo "Дата бекапа: ${RESTORE_DATE}"
echo "Конфиги: ${CONFIG_BACKUP_DIR}"
echo "=========================================="
echo ""
echo "🔗 Доступ к qBittorrent: http://localhost:${QBITTORRENT_LOCAL_PORT:-8082}"
echo "📋 Логи: docker compose logs -f torrent"
echo "📥 Загрузки не затрагивались — файлы на месте"
echo "=========================================="