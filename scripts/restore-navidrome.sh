#!/bin/bash
# restore-navidrome.sh — Восстановление Navidrome из бекапа
# Восстанавливает только БД + конфиги (музыка не затрагивается)

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
NAVIDROME_DATA_PATH="./volumes/navidrome/data"

# 🔥 Преобразуем относительный путь в абсолютный
PROJECT_DIR="$(dirname "$ENV_FILE")"
if [[ "$NAVIDROME_DATA_PATH" == /* ]]; then
    # Уже абсолютный путь
    NAVIDROME_DATA_PATH_ABS="$NAVIDROME_DATA_PATH"
else
    # Относительный путь — преобразуем в абсолютный относительно проекта
    NAVIDROME_DATA_PATH_ABS="$(cd "$PROJECT_DIR" && realpath -m "$NAVIDROME_DATA_PATH")"
fi



# =====================================================
# Функции
# =====================================================
log() {
    echo "[$(date '+%F %T')] $1"
}

error_exit() {
    log "❌ ОШИБКА: $1"
    docker compose start "$NAVIDROME_CONTAINER" 2>/dev/null || true
    exit 1
}

# Показать доступные бекапы
list_backups() {
    echo ""
    echo "📋 Доступные бекапы:"
    echo "=========================================="
    if [ -d "$NAVIDROME_BACKUP_DIR" ]; then
        find "$NAVIDROME_BACKUP_DIR" -maxdepth 1 -type d -name "20*" | sort -r | while read -r dir; do
            DATE=$(basename "$dir")
            DATA_DIR="$dir/data"

            if [ -d "$DATA_DIR" ]; then
                DATA_SIZE=$(du -sh "$DATA_DIR" | cut -f1)
                DB_FILE=$(find "$DATA_DIR" -name "*.db" -type f 2>/dev/null | head -1)
                if [ -n "$DB_FILE" ]; then
                    DB_SIZE=$(du -h "$DB_FILE" | cut -f1)
                    echo "  $DATE  |  БД: $DB_SIZE  |  Всего: $DATA_SIZE"
                else
                    echo "  $DATE  |  ❌ нет БД  |  Всего: $DATA_SIZE"
                fi
            else
                echo "  $DATE  |  ❌ нет данных"
            fi
        done
    else
        echo "  ❌ Директория бекапов не найдена: $NAVIDROME_BACKUP_DIR"
    fi
    echo "=========================================="
    echo ""
}

# =====================================================
# Основной процесс
# =====================================================
log "🚀 Восстановление Navidrome из бекапа"
log "📁 .env файл: ${ENV_FILE}"
log "📁 Путь бекапов: ${NAVIDROME_BACKUP_DIR}"
log "📁 Navidrome data: ${NAVIDROME_DATA_PATH}"

# Проверка наличия бекапов
if [ ! -d "$NAVIDROME_BACKUP_DIR" ]; then
    error_exit "Директория бекапов не найдена: $NAVIDROME_BACKUP_DIR"
fi

# Показать доступные бекапы
list_backups

# Получить дату для восстановления
RESTORE_DATE="$1"

if [ -z "$RESTORE_DATE" ]; then
    echo "Введите дату для восстановления (YYYY-MM-DD) или 'q' для выхода:"
    read -r RESTORE_DATE

    if [ "$RESTORE_DATE" = "q" ] || [ -z "$RESTORE_DATE" ]; then
        log "❌ Восстановление отменено"
        exit 0
    fi
fi

# Проверка существования бекапа
BACKUP_DIR="${NAVIDROME_BACKUP_DIR}/${RESTORE_DATE}"
DATA_BACKUP_DIR="${BACKUP_DIR}/data"

if [ ! -d "$BACKUP_DIR" ]; then
    error_exit "Бекап не найден: $BACKUP_DIR"
fi

if [ ! -d "$DATA_BACKUP_DIR" ]; then
    error_exit "Данные не найдены: $DATA_BACKUP_DIR"
fi

# Проверка наличия БД
DB_FILE=$(find "$DATA_BACKUP_DIR" -name "*.db" -type f 2>/dev/null | head -1)
if [ -z "$DB_FILE" ]; then
    error_exit "База данных не найдена в бекапе: $DATA_BACKUP_DIR"
fi

# Предупреждение
echo ""
echo "⚠️  ВНИМАНИЕ! ⚠️"
echo "=========================================="
echo "Текущие данные Navidrome будут ЗАМЕНЕНЫ на бекап от ${RESTORE_DATE}"
echo ""
echo "Источник: ${DATA_BACKUP_DIR}"
echo "Назначение: ${NAVIDROME_DATA_PATH}"
echo ""
echo "🎵 Музыка НЕ будет затронута (монтируется отдельно)"
echo ""
read -r -p "Продолжить? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log "❌ Восстановление отменено пользователем"
    exit 0
fi

# =====================================================
# Начало восстановления
# =====================================================
log "🛑 Остановка контейнера $NAVIDROME_CONTAINER..."
docker compose stop "$NAVIDROME_CONTAINER" || error_exit "Не удалось остановить Navidrome"
log "✅ Navidrome остановлен"

# 1. Восстановление данных (БД + конфиги + кэш)
log "📁 Восстановление данных (rsync)..."
log "🗑️ Очистка текущих данных..."

# Удаляем текущие данные (кроме музыкальной библиотеки — она монтируется отдельно)
rm -rf "${NAVIDROME_DATA_PATH:?}"/*

# Копируем из бекапа
rsync -av --delete \
    "${DATA_BACKUP_DIR}/" \
    "${NAVIDROME_DATA_PATH}/" || error_exit "Не удалось восстановить данные"

log "✅ Данные восстановлены"

# 2. Исправить права (если нужно)
log "🔐 Проверка прав доступа..."
chown -R 1000:1000 "${NAVIDROME_DATA_PATH}" 2>/dev/null || true
log "✅ Права проверены"

# 3. Запустить Navidrome
log "▶️ Запуск контейнера $NAVIDROME_CONTAINER..."
docker compose start "$NAVIDROME_CONTAINER" || error_exit "Не удалось запустить Navidrome"
log "✅ Navidrome запущен"

# 4. Проверка
log "⏳ Ожидание запуска Navidrome (15 сек)..."
sleep 15

if docker compose ps | grep -q "navidrome.*Up"; then
    log "✅ Navidrome работает"
else
    log "⚠️  Navidrome может иметь проблемы. Проверьте логи: docker compose logs navidrome"
fi

# 5. Финал
log "🎉 Восстановление завершено успешно!"
log "📍 Дата бекапа: ${RESTORE_DATE}"

echo ""
echo "=========================================="
echo "📊 Сводка восстановления"
echo "=========================================="
echo "Дата бекапа: ${RESTORE_DATE}"
echo "Данные: ${DATA_BACKUP_DIR}"
echo "=========================================="
echo ""
echo "🔗 Доступ к Navidrome: https://${NAVIDROME_DOMAIN}"
echo "📋 Логи: docker compose logs -f navidrome"
echo "🎵 Музыка не затрагивалась — библиотека на месте"
echo "=========================================="