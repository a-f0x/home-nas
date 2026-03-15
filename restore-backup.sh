#!/bin/bash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BACKUP_DIR="./volumes/backup/pg/nextcloud"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Загружаем переменные из .env
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(cat "$SCRIPT_DIR/.env" | grep -v '^#' | xargs)
else
    echo -e "${RED}Ошибка: файл .env не найден${NC}"
    exit 1
fi

echo -e "${GREEN}=== Скрипт восстановления бекапа PostgreSQL ===${NC}\n"

# Проверяем наличие директории с бекапами
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}Ошибка: директория с бекапами не найдена: $BACKUP_DIR${NC}"
    exit 1
fi

# Получаем список бекапов (ищем во всех подпапках)
echo -e "${YELLOW}Доступные бекапы:${NC}\n"
backups=($(find "$BACKUP_DIR" -name "*.sql.gz" -type f 2>/dev/null | sort -r || true))

if [ ${#backups[@]} -eq 0 ]; then
    echo -e "${RED}Бекапы не найдены в $BACKUP_DIR${NC}"
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

# Запрашиваем выбор пользователя
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

# Подтверждение
echo -e "${RED}ВНИМАНИЕ! Текущая база данных будет полностью удалена и заменена на выбранный бекап.${NC}"
echo -ne "${YELLOW}Вы уверены? (yes/no): ${NC}"
read confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Отменено пользователем"
    exit 0
fi

echo -e "\n${GREEN}Начинаем восстановление...${NC}\n"

# Останавливаем Nextcloud (но оставляем БД работать)
echo -e "${YELLOW}[1/5] Останавливаем Nextcloud...${NC}"
docker-compose stop nextcloud
echo -e "${GREEN}✓ Nextcloud остановлен${NC}\n"

# Проверяем, что контейнер БД запущен
echo -e "${YELLOW}[2/5] Проверяем контейнер базы данных...${NC}"
if ! docker-compose ps db | grep -q "Up"; then
    echo -e "${YELLOW}Запускаем контейнер БД...${NC}"
    docker-compose up -d db
    echo "Ожидаем запуска PostgreSQL..."
    sleep 5
fi
echo -e "${GREEN}✓ Контейнер БД запущен${NC}\n"

# Дропаем и создаём базу данных заново
echo -e "${YELLOW}[3/5] Пересоздаём базу данных...${NC}"
docker-compose exec -T db psql -U "$POSTGRES_USER" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$POSTGRES_DB' AND pid <> pg_backend_pid();"
docker-compose exec -T db psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS $POSTGRES_DB;"
docker-compose exec -T db psql -U "$POSTGRES_USER" -c "CREATE DATABASE $POSTGRES_DB OWNER $POSTGRES_NC_USER;"
echo -e "${GREEN}✓ База данных пересоздана${NC}\n"

# Восстанавливаем бекап
echo -e "${YELLOW}[4/5] Восстанавливаем бекап...${NC}"
gunzip -c "$selected_backup" | docker-compose exec -T db psql -U "$POSTGRES_NC_USER" -d "$POSTGRES_DB"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Бекап успешно восстановлен${NC}\n"
else
    echo -e "${RED}✗ Ошибка при восстановлении бекапа${NC}\n"
    exit 1
fi

# Запускаем Nextcloud обратно
echo -e "${YELLOW}[5/5] Запускаем Nextcloud...${NC}"
docker-compose up -d nextcloud
echo -e "${GREEN}✓ Nextcloud запущен${NC}\n"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Восстановление завершено успешно!${NC}"
echo -e "${GREEN}========================================${NC}\n"
echo -e "Nextcloud доступен по адресу: http://localhost:8080"
