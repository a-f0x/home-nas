#!/bin/bash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE_DIR="./volumes/backup/pg"

# Загружаем переменные из .env
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(cat "$SCRIPT_DIR/.env" | grep -v '^#' | xargs)
else
    echo -e "${RED}Ошибка: файл .env не найден${NC}"
    exit 1
fi

echo -e "${GREEN}=== Скрипт восстановления бекапа PostgreSQL ===${NC}\n"

# Получаем список доступных БД (по папкам в директории бекапов)
if [ ! -d "$BACKUP_BASE_DIR" ]; then
    echo -e "${RED}Ошибка: директория с бекапами не найдена: $BACKUP_BASE_DIR${NC}"
    exit 1
fi

db_dirs=($(find "$BACKUP_BASE_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort))

if [ ${#db_dirs[@]} -eq 0 ]; then
    echo -e "${RED}Не найдено баз данных для восстановления${NC}"
    exit 1
fi

# Если передан аргумент - используем его, иначе показываем выбор
if [ -n "$1" ]; then
    DB_NAME="$1"
    # Проверяем, что такая БД существует
    if [ ! -d "$BACKUP_BASE_DIR/$DB_NAME" ]; then
        echo -e "${RED}Ошибка: база данных '$DB_NAME' не найдена${NC}"
        echo -e "${YELLOW}Доступные базы данных:${NC}"
        for db in "${db_dirs[@]}"; do
            echo "  - $db"
        done
        exit 1
    fi
else
    # Показываем выбор БД
    echo -e "${BLUE}Выберите базу данных для восстановления:${NC}\n"
    for i in "${!db_dirs[@]}"; do
        db_name="${db_dirs[$i]}"
        backup_count=$(find "$BACKUP_BASE_DIR/$db_name" -name "*.sql.gz" -type f 2>/dev/null | wc -l)
        echo -e "$((i+1))) $db_name"
        echo -e "   Доступно бекапов: $backup_count\n"
    done
    
    echo -ne "${YELLOW}Выберите номер базы данных (или 'q' для выхода): ${NC}"
    read db_choice
    
    if [ "$db_choice" = "q" ] || [ "$db_choice" = "Q" ]; then
        echo "Отменено пользователем"
        exit 0
    fi
    
    if ! [[ "$db_choice" =~ ^[0-9]+$ ]] || [ "$db_choice" -lt 1 ] || [ "$db_choice" -gt ${#db_dirs[@]} ]; then
        echo -e "${RED}Некорректный выбор${NC}"
        exit 1
    fi
    
    DB_NAME="${db_dirs[$((db_choice-1))]}"
fi

echo -e "\n${GREEN}База данных: $DB_NAME${NC}\n"

BACKUP_DIR="$BACKUP_BASE_DIR/$DB_NAME"

# Получаем список бекапов для выбранной БД
echo -e "${YELLOW}Доступные бекапы для $DB_NAME:${NC}\n"
backups=($(find "$BACKUP_DIR" -name "*.sql.gz" -type f 2>/dev/null | sort -r || true))

if [ ${#backups[@]} -eq 0 ]; then
    echo -e "${RED}Бекапы не найдены для $DB_NAME${NC}"
    exit 1
fi

# Выводим список бекапов
for i in "${!backups[@]}"; do
    backup_file=$(basename "${backups[$i]}")
    backup_size=$(du -h "${backups[$i]}" | cut -f1)
    backup_date=$(stat -c %y "${backups[$i]}" | cut -d'.' -f1)
    echo -e "$((i+1))) $backup_file"
    echo -e "   Размер: $backup_size | Дата: $backup_date\n"
done

# Запрашиваем выбор бекапа
echo -ne "${YELLOW}Выберите номер бекапа для восстановления (или 'q' для выхода): ${NC}"
read choice

if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
    echo "Отменено пользователем"
    exit 0
fi

# Проверяем корректность выбора
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
    echo -e "${RED}Некорректный выбор${NC}"
    exit 1
fi

selected_backup="${backups[$((choice-1))]}"
echo -e "\n${GREEN}Выбран бекап: $(basename "$selected_backup")${NC}\n"

# Определяем параметры БД из .env
case $DB_NAME in
    "nextcloud")
        DB_USER="${POSTGRES_NC_USER}"
        DB_PASSWORD="${POSTGRES_NC_PASSWORD}"
        SERVICE_NAME="nextcloud"
        DB_CONTAINER="db"
        ;;
    # Добавьте здесь другие БД
    # "another-db")
    #     DB_USER="${ANOTHER_DB_USER}"
    #     DB_PASSWORD="${ANOTHER_DB_PASSWORD}"
    #     SERVICE_NAME="another-service"
    #     DB_CONTAINER="db"
    #     ;;
    *)
        echo -e "${RED}Ошибка: конфигурация для БД '$DB_NAME' не найдена${NC}"
        echo -e "${YELLOW}Добавьте параметры БД в скрипт${NC}"
        exit 1
        ;;
esac

# Подтверждение
echo -e "${RED}ВНИМАНИЕ! База данных '$DB_NAME' будет полностью удалена и заменена на выбранный бекап.${NC}"
echo -ne "${YELLOW}Вы уверены? (yes/no): ${NC}"
read confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Отменено пользователем"
    exit 0
fi

echo -e "\n${GREEN}Начинаем восстановление...${NC}\n"

# Останавливаем зависимые сервисы
if [ -n "$SERVICE_NAME" ]; then
    echo -e "${YELLOW}[1/5] Останавливаем сервис $SERVICE_NAME...${NC}"
    docker-compose stop "$SERVICE_NAME"
    echo -e "${GREEN}✓ Сервис $SERVICE_NAME остановлен${NC}\n"
fi

# Проверяем, что контейнер БД запущен
echo -e "${YELLOW}[2/5] Проверяем контейнер базы данных...${NC}"
if ! docker-compose ps "$DB_CONTAINER" | grep -q "Up"; then
    echo -e "${YELLOW}Запускаем контейнер БД...${NC}"
    docker-compose up -d "$DB_CONTAINER"
    echo "Ожидаем запуска PostgreSQL..."
    sleep 5
fi
echo -e "${GREEN}✓ Контейнер БД запущен${NC}\n"

# Дропаем и создаём базу данных заново
echo -e "${YELLOW}[3/5] Пересоздаём базу данных $DB_NAME...${NC}"
docker-compose exec -T "$DB_CONTAINER" psql -U "$POSTGRES_USER" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"
docker-compose exec -T "$DB_CONTAINER" psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS $DB_NAME;"
docker-compose exec -T "$DB_CONTAINER" psql -U "$POSTGRES_USER" -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
echo -e "${GREEN}✓ База данных пересоздана${NC}\n"

# Восстанавливаем бекап
echo -e "${YELLOW}[4/5] Восстанавливаем бекап...${NC}"
gunzip -c "$selected_backup" | docker-compose exec -T "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Бекап успешно восстановлен${NC}\n"
else
    echo -e "${RED}✗ Ошибка при восстановлении бекапа${NC}\n"
    exit 1
fi

# Запускаем сервисы обратно
if [ -n "$SERVICE_NAME" ]; then
    echo -e "${YELLOW}[5/5] Запускаем сервис $SERVICE_NAME...${NC}"
    docker-compose up -d "$SERVICE_NAME"
    echo -e "${GREEN}✓ Сервис $SERVICE_NAME запущен${NC}\n"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Восстановление завершено успешно!${NC}"
echo -e "${GREEN}========================================${NC}\n"
echo -e "База данных: ${BLUE}$DB_NAME${NC}"
