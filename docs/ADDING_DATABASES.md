# Добавление новых приложений с базами данных

Этот файл содержит готовые шаблоны для добавления различных приложений с базами данных в ваш проект.

## 📑 Оглавление

- [Архитектура проекта](#архитектура-проекта)
- [Добавление приложения с PostgreSQL](#добавление-приложения-с-postgresql)
- [Полезные команды](#полезные-команды)

---

## Архитектура проекта

В проекте используется **единый контейнер PostgreSQL** (`db`) для всех приложений, которым нужна база данных.

**Преимущества:**
- ✅ Меньше ресурсов (RAM, CPU)
- ✅ Единая точка управления
- ✅ Простота бэкапов
- ✅ Меньше контейнеров

**Все новые приложения подключаются к единому контейнеру `db`.**

---

## Добавление приложения с PostgreSQL

### Пример: WordPress

Добавляем WordPress, который будет использовать существующий контейнер `db`.

#### 1. Обновите docker/postgres/init.sql:

```sql
-- Nextcloud (уже есть)
CREATE DATABASE nextcloud;
CREATE USER nextclouduser WITH ENCRYPTED PASSWORD 'nextcloud-password';
ALTER DATABASE nextcloud OWNER TO nextclouduser;
GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextclouduser;
GRANT ALL ON SCHEMA public TO nextclouduser;

-- WordPress (добавить)
CREATE DATABASE wordpress;
CREATE USER wpuser WITH ENCRYPTED PASSWORD 'wordpress-password';
ALTER DATABASE wordpress OWNER TO wpuser;
GRANT ALL PRIVILEGES ON DATABASE wordpress TO wpuser;
GRANT ALL ON SCHEMA public TO wpuser;
```

#### 2. Добавьте в .env:

```bash
# WordPress Database
WORDPRESS_DB=wordpress
WORDPRESS_DB_USER=wpuser
WORDPRESS_DB_PASSWORD=secure-password-here
WORDPRESS_DOMAIN=blog.ton618.ru
```

#### 3. Добавьте в docker-compose.yml:

```yaml
  # Бекап для WordPress
  wordpress-backup:
    image: prodrigestivill/postgres-backup-local
    restart: always
    environment:
      POSTGRES_HOST: db
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_ROOT_PASSWORD}
      POSTGRES_DB: ${WORDPRESS_DB}
      SCHEDULE: 0 3 * * *
      BACKUP_KEEP_DAYS: 7
    volumes:
      - ./volumes/backup/pg/wordpress:/backups

  wordpress:
    image: wordpress
    restart: always
    depends_on:
      - db
    environment:
      WORDPRESS_DB_HOST: db:5432
      WORDPRESS_DB_NAME: ${WORDPRESS_DB}
      WORDPRESS_DB_USER: ${WORDPRESS_DB_USER}
      WORDPRESS_DB_PASSWORD: ${WORDPRESS_DB_PASSWORD}
    volumes:
      - ./volumes/wordpress:/var/www/html
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress.rule=Host(`${WORDPRESS_DOMAIN}`)"
      - "traefik.http.routers.wordpress.entrypoints=websecure"
      - "traefik.http.routers.wordpress.tls.certresolver=letsencrypt"
      - "traefik.http.services.wordpress.loadbalancer.server.port=80"
```

#### 4. Добавьте в restore-backup-multi.sh:

```bash
    "wordpress")
        DB_USER="${WORDPRESS_DB_USER}"
        DB_PASSWORD="${WORDPRESS_DB_PASSWORD}"
        SERVICE_NAME="wordpress"
        DB_CONTAINER="db"
        ;;
```

#### 5. Запустите:

```bash
# Пересоздайте БД контейнер для применения init.sql
docker-compose down db
docker-compose up -d

# Или если БД уже существует, создайте БД вручную:
docker-compose exec db psql -U postgres -c "CREATE DATABASE wordpress;"
docker-compose exec db psql -U postgres -c "CREATE USER wpuser WITH ENCRYPTED PASSWORD 'your-password';"
docker-compose exec db psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE wordpress TO wpuser;"

# Запустите WordPress
docker-compose up -d wordpress
```

---

## Полезные команды

```bash
# Создать БД вручную в существующем PostgreSQL
docker-compose exec db psql -U postgres -c "CREATE DATABASE newdb;"
docker-compose exec db psql -U postgres -c "CREATE USER newuser WITH ENCRYPTED PASSWORD 'password';"
docker-compose exec db psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE newdb TO newuser;"

# Список всех БД
docker-compose exec db psql -U postgres -c "\l"

# Список пользователей
docker-compose exec db psql -U postgres -c "\du"

# Удалить БД
docker-compose exec db psql -U postgres -c "DROP DATABASE dbname;"

# Восстановить из бэкапа
./scripts/restore-backup-multi.sh <app-name> <backup-file>
```

