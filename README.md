# Home Server Setup

Домашний сервер с различными self-hosted приложениями, единой базой данных PostgreSQL и автоматическим резервным копированием.

## 📑 Оглавление

- [Обзор](#обзор)
- [Архитектура](#архитектура)
- [Быстрый старт](#быстрый-старт)
- [Приложения](#приложения)
  - [Nextcloud](#nextcloud)
  - [Navidrome](#navidrome)
  - [Добавление новых приложений](#добавление-новых-приложений)
- [Инфраструктура](#инфраструктура)
  - [PostgreSQL](#postgresql)
  - [Резервное копирование](#резервное-копирование)
  - [Восстановление из бекапа](#восстановление-из-бекапа)
- [Управление](#управление)
  - [Переменные окружения](#переменные-окружения-env)
  - [Полезные команды](#полезные-команды)
- [Безопасность](#безопасность)
- [Troubleshooting](#troubleshooting)

## 📚 Дополнительная документация

- 📖 [Примеры добавления приложений](docs/ADDING_DATABASES.md) - WordPress, GitLab, другие приложения
- 📐 [Архитектура системы](docs/ARCHITECTURE.md) - диаграммы, сравнение подходов
- 🔒 [Настройка HTTPS с Traefik](docs/TRAEFIK_SETUP.md) - доступ из интернета, SSL сертификаты
- 🎵 [Navidrome](docs/NAVIDROME.md) - музыкальный стриминг-сервер
- 🌊 [qBittorrent](docs/QBITTORRENT.md) - торрент-клиент

---

## Обзор

Этот проект представляет собой полностью контейнеризированный домашний сервер с:

- 🗄️ **Единый PostgreSQL** - одна база данных для всех приложений
- ☁️ **Nextcloud** - облачное хранилище
- 🎵 **Navidrome** - музыкальный стриминг-сервер
- 🌊 **qBittorrent** - торрент-клиент
- 💾 **Автоматические бекапы** - ежедневное резервное копирование всех БД
- 🔄 **Простое масштабирование** - добавление новых приложений за 5 минут
- 🔒 **Безопасность** - пароли в `.env`, изоляция контейнеров

### Что можно добавить:

- WordPress / Ghost (блоги)
- GitLab / Gitea (Git-репозитории)
- Bitwarden / Vaultwarden (менеджер паролей)
- Jellyfin / Plex (медиа-сервер)
- Home Assistant (умный дом)
- Любое приложение с поддержкой PostgreSQL

---

## Архитектура

```
┌─────────────────────────────────────────────┐
│                   Home Server               │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │Nextcloud │  │Navidrome │  │ [Другие] │   │
│  │  :8080   │  │  :4533   │  │          │   │
│  └────┬─────┘  └─────┬────┘  └────┬─────┘   │
│       │              │            │         │
│       │              │ (SQLite)   │         │
│       └──────────────┼────────────┘         │
│                      ▼                      │
│            ┌─────────────────────┐          │
│            │   PostgreSQL :5432   │         │
│            │  ┌─────────────────┐│          │
│            │  │ DB: nextcloud   ││          │
│            │  │ DB: [others]    ││          │
│            │  └─────────────────┘│          │
│            └──────────┬──────────┘          │
│                       │                     │
│          ┌────────────▼────────────┐        │
│          │   Backup Services       │        │
│          │  (по одному для БД)     │        │
│          └────────────┬────────────┘        │
│                       │                     │
│          volumes/backup/pg/                 │
│          ├── nextcloud/                     │
│          └── [others]/                      │
└─────────────────────────────────────────────┘
```

---

## Быстрый старт

### 1. Настройте переменные окружения

```bash
cp .env.example .env
nano .env
```

Измените пароли для безопасности! При необходимости можете изменить порты для локального доступа:
- `NEXTCLOUD_LOCAL_PORT` (по умолчанию 8081)
- `NAVIDROME_LOCAL_PORT` (по умолчанию 4533)
- `TRAEFIK_DASHBOARD_PORT` (по умолчанию 8080)
- `POSTGRES_PORT` (по умолчанию 5432)

⚠️ **Эти порты НЕ должны пробрасываться на роутере - только для локальной сети!**

### 2. Запустите инфраструктуру

```bash
# Запустить PostgreSQL и бекапы
docker-compose up -d db db-backup

# Дождаться запуска БД (5-10 секунд)
sleep 10
```

### 3. Запустите приложения

```bash
# Запустить Nextcloud
docker-compose up -d nextcloud

# Добавьте другие приложения по мере необходимости
```

### 4. Настройте приложения

- **Nextcloud**: http://localhost:8081 (NEXTCLOUD_LOCAL_PORT)

---

## Приложения

### Nextcloud

**Облачное хранилище** - аналог Dropbox/Google Drive

- **Порт**: Настраивается через `NEXTCLOUD_LOCAL_PORT` в .env (по умолчанию 8081)
- **База данных**: `nextcloud`
- **Данные**: `./volumes/nextcloud/`

#### Первоначальная настройка:

1. Откройте http://localhost:8081 (или измените NEXTCLOUD_LOCAL_PORT в .env)
2. Создайте администратора
3. Настройте доверенные домены (если нужен доступ по IP)

---

### Navidrome

**Музыкальный стриминг-сервер** - аналог Spotify/Subsonic для вашей музыки

- **Порт**: Настраивается через `NAVIDROME_LOCAL_PORT` в .env (по умолчанию 4533)
- **База данных**: SQLite (не использует PostgreSQL)
- **Данные**: `./volumes/navidrome/data/`
- **Музыка**: Настраивается через переменную `NAVIDROME_MUSIC_PATH`

#### Первоначальная настройка:

1. **Укажите путь к музыке** в `.env`:
   ```bash
   NAVIDROME_MUSIC_PATH=/path/to/your/music
   ```

2. **Запустите Navidrome**:
   ```bash
   docker-compose up -d navidrome
   ```

3. **Откройте** https://music.yourdomain.com (или локально)

4. **При первом входе** создайте администратора

#### Особенности:

- ✅ Не требует PostgreSQL (использует встроенную SQLite)
- ✅ Автоматически сканирует библиотеку каждый час
- ✅ Поддержка Subsonic API (работает с мобильными клиентами)
- ✅ Web-интерфейс для прослушивания

#### Мобильные клиенты:

**Android:**
- DSub
- Ultrasonic
- Symfonium

**iOS:**
- play:Sub
- substreamer

**Настройка клиента:**
- Server: `https://music.yourdomain.com`
- Username: ваш логин
- Password: ваш пароль

#### Бекап:

⚠️ Бекап для Navidrome пока не настроен. SQLite база находится в `volumes/navidrome/data/navidrome.db`.

---

### Добавление новых приложений

> 📖 **Подробные примеры**: [docs/ADDING_DATABASES.md](docs/ADDING_DATABASES.md)

#### Быстрый гайд (3 шага):

**Шаг 1**: Добавьте переменные в `.env`

```bash
# Новое приложение
NEWAPP_DB=newapp
NEWAPP_DB_USER=newappuser
NEWAPP_DB_PASSWORD=secure-password
```

**Шаг 2**: Обновите `docker/postgres/init.sql`

```sql
-- Новое приложение
CREATE DATABASE newapp;
CREATE USER newappuser WITH ENCRYPTED PASSWORD 'secure-password';
ALTER DATABASE newapp OWNER TO newappuser;
GRANT ALL PRIVILEGES ON DATABASE newapp TO newappuser;
GRANT ALL ON SCHEMA public TO newappuser;
```

**Шаг 3**: Добавьте сервисы в `docker-compose.yml`

```yaml
  # Само приложение
  newapp:
    image: newapp-image
    ports:
      - "8082:80"
    depends_on:
      - db
    environment:
      DB_HOST: db
      DB_NAME: ${NEWAPP_DB}
      DB_USER: ${NEWAPP_DB_USER}
      DB_PASSWORD: ${NEWAPP_DB_PASSWORD}

  # Бекап для приложения
  newapp-backup:
    image: prodrigestivill/postgres-backup-local
    restart: always
    environment:
      POSTGRES_HOST: db
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_ROOT_PASSWORD}
      POSTGRES_DB: ${NEWAPP_DB}
      SCHEDULE: "0 2 * * *"
      BACKUP_KEEP_DAYS: 7
    volumes:
      - ./volumes/backup/pg/newapp:/backups
```

**Шаг 4**: Обновите `restore-backup-multi.sh`

```bash
    "newapp")
        DB_USER="${NEWAPP_DB_USER}"
        DB_PASSWORD="${NEWAPP_DB_PASSWORD}"
        SERVICE_NAME="newapp"
        DB_CONTAINER="db"
        ;;
```

---

## Инфраструктура

### PostgreSQL

**Единая база данных** для всех приложений на сервере.

- **Порт**: Настраивается через `POSTGRES_PORT` в .env (по умолчанию 5432, локальный доступ)
- **Версия**: 18.3-alpine
- **Данные**: `./volumes/pg_data/`
- **Инициализация**: `./docker/postgres/init.sql`

#### Подключение к БД:

```bash
# Общее подключение
docker-compose exec db psql -U postgres

# Конкретная БД
docker-compose exec db psql -U nextclouduser -d nextcloud
```

#### Список всех баз данных:

```bash
docker-compose exec db psql -U postgres -c "\l"
```

---

### Резервное копирование

> 📖 **Подробная документация**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

#### Автоматическое

- ⏰ **Расписание**: ежедневно в 02:00
- 📅 **Хранение**: последние 7 дней
- 📁 **Папка**: `./volumes/backup/pg/<database>/`
- 🔄 **Тип**: инкрементальное (daily/weekly/monthly)

#### Структура бекапов

```
volumes/backup/pg/
├── nextcloud/
│   ├── daily/
│   ├── weekly/
│   ├── monthly/
│   └── last/
├── wordpress/
│   └── daily/
└── gitea/
    └── daily/
```

#### Ручное создание бекапа

```bash
# Бекап конкретной БД
docker-compose exec db pg_dump -U postgres nextcloud | \
  gzip > backup-nextcloud-$(date +%Y%m%d-%H%M%S).sql.gz

# Бекап всех БД
docker-compose exec db pg_dumpall -U postgres | \
  gzip > backup-all-$(date +%Y%m%d-%H%M%S).sql.gz
```

---

### Восстановление из бекапа

#### Универсальный скрипт (рекомендуется)

```bash
# Интерактивный режим - выбор БД и бекапа
./restore-backup-multi.sh

# Прямое указание БД
./restore-backup-multi.sh nextcloud
```

**Пример работы:**

```
=== Скрипт восстановления бекапа PostgreSQL ===

Выберите базу данных для восстановления:

1) nextcloud
   Доступно бекапов: 5

2) wordpress
   Доступно бекапов: 3

Выберите номер базы данных (или 'q' для выхода): 1
```

#### Что делает скрипт:

1. ✅ Показывает список всех БД на сервере
2. ✅ Показывает бекапы с датой и размером
3. ✅ Останавливает зависимое приложение
4. ✅ Завершает все подключения к БД
5. ✅ Пересоздаёт базу данных
6. ✅ Восстанавливает данные из бекапа
7. ✅ Запускает приложение обратно

⚠️ **Внимание**: Текущая база данных будет полностью заменена!

#### Простой скрипт (только для Nextcloud)

```bash
./restore-backup.sh
```

---

## Управление

### Переменные окружения (.env)

#### PostgreSQL (общие)
```bash
POSTGRES_PORT=5432  # Локальный доступ
POSTGRES_ROOT_PASSWORD=...  # Root пароль PostgreSQL
POSTGRES_USER=postgres       # Root пользователь
```

#### Приложения

**Nextcloud**
```bash
NEXTCLOUD_LOCAL_PORT=8081  # Локальный доступ
NEXTCLOUD_DOMAIN=home.yourdomain.com
POSTGRES_NC_DB=nextcloud
POSTGRES_NC_USER=nextclouduser
POSTGRES_NC_PASSWORD=...
```

**Navidrome**
```bash
NAVIDROME_LOCAL_PORT=4533  # Локальный доступ
NAVIDROME_DOMAIN=music.yourdomain.com
NAVIDROME_MUSIC_PATH=/path/to/your/music
```

**Добавьте свои приложения**
```bash
WORDPRESS_DB=wordpress
WORDPRESS_DB_USER=wpuser
WORDPRESS_DB_PASSWORD=...
```

---

### Полезные команды

#### Общие

```bash
# Статус всех сервисов
docker-compose ps

# Просмотр логов
docker-compose logs -f

# Перезапуск всех сервисов
docker-compose restart

# Остановка
docker-compose down

# Обновление образов
docker-compose pull
docker-compose up -d
```

#### PostgreSQL

```bash
# Список баз данных
docker-compose exec db psql -U postgres -c "\l"

# Размер баз данных
docker-compose exec db psql -U postgres -c "\l+"

# Список активных подключений
docker-compose exec db psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

#### Бекапы

```bash
# Список всех бекапов
find volumes/backup/pg/ -name "*.sql.gz" -type f | sort

# Проверка целостности бекапа
gunzip -t volumes/backup/pg/nextcloud/daily/nextcloud-20260315.sql.gz

# Размер бекапов
du -sh volumes/backup/pg/*
```

#### Мониторинг

```bash
# Использование дисков
df -h

# Использование ресурсов контейнерами
docker stats

# Логи за последние 100 строк
docker-compose logs --tail=100 nextcloud
```

---

## Структура директорий

```
home-server/
├── docker/
│   ├── postgres/
│   │   └── init.sql              # Инициализация всех БД
│   └── nextcloud/
│       └── config.php            # Конфигурация (опционально)
├── docs/
│   ├── ADDING_DATABASES.md       # Примеры приложений
│   └── ARCHITECTURE.md           # Архитектура системы
├── volumes/                      # Данные (не в git)
│   ├── pg_data/                  # PostgreSQL данные
│   ├── backup/pg/                # Бекапы всех БД
│   │   ├── nextcloud/
│   │   ├── wordpress/
│   │   └── gitea/
│   ├── nextcloud/                # Данные Nextcloud
│   ├── wordpress/                # Данные WordPress
│   └── gitea/                    # Данные Gitea
├── .env                          # Переменные окружения
├── .env.example                  # Шаблон
├── .gitignore
├── docker-compose.yml            # Конфигурация всех сервисов
├── restore-backup.sh             # Простой скрипт (1 БД)
├── restore-backup-multi.sh       # Универсальный скрипт
└── README.md                     # Этот файл
```

---

## Безопасность

### ⚠️ Обязательно:

- ✅ Измените **все** пароли в `.env`
- ✅ Не комитьте `.env` в git
- ✅ **НЕ пробрасывайте на роутере** порты для локального доступа:
  - `POSTGRES_PORT` (5432) - PostgreSQL
  - `NEXTCLOUD_LOCAL_PORT` (8081) - Nextcloud
  - `NAVIDROME_LOCAL_PORT` (4533) - Navidrome  
  - `TRAEFIK_DASHBOARD_PORT` (8080) - Traefik Dashboard
- ✅ **Пробрасывайте только** порты 80 и 443 для Traefik (HTTPS доступ из интернета)
- ✅ Регулярно проверяйте бекапы (тестовое восстановление)
- ✅ Настройте файрвол на сервере

### Рекомендуется для production:

- 🔒 **Reverse proxy** (Nginx/Caddy/Traefik) с HTTPS
- 🔒 **Fail2ban** для защиты от брутфорса
- 🔒 **VPN** (WireGuard/Tailscale) для удалённого доступа
- 🔒 **Мониторинг** (Prometheus + Grafana)
- 🔒 **Offsite бекапы** (синхронизация на S3/другой сервер)

### Проверка безопасности:

```bash
# Проверить открытые порты
sudo netstat -tulpn | grep LISTEN

# Проверить, что .env не в git
git status --ignored

# Проверить права доступа
ls -la .env
# Должно быть: -rw------- (600)
```

---

## Troubleshooting

### PostgreSQL не запускается

```bash
# Проверить логи
docker-compose logs db

# Проверить права доступа
ls -la volumes/pg_data/

# Пересоздать контейнер
docker-compose down db
docker-compose up -d db
```

### Приложение не подключается к БД

```bash
# Проверить, что БД создана
docker-compose exec db psql -U postgres -c "\l"

# Проверить пользователя
docker-compose exec db psql -U postgres -c "\du"

# Проверить переменные окружения
docker-compose config
```

### Бекапы не создаются

```bash
# Проверить логи бекап-сервиса
docker-compose logs db-backup

# Проверить папку бекапов
ls -la volumes/backup/pg/nextcloud/

# Вручную запустить бекап
docker-compose exec db pg_dump -U postgres nextcloud
```

### Nextcloud: "Trusted domain error"

Добавьте ваш IP/домен в `volumes/nextcloud/config/config.php`:

```php
'trusted_domains' => 
  array (
    0 => 'localhost:8080',
    1 => '192.168.1.100:8080',  // Ваш локальный IP
  ),
```

### Проблемы с правами доступа

```bash
# Nextcloud
sudo chown -R www-data:www-data volumes/nextcloud

# PostgreSQL
sudo chown -R 999:999 volumes/pg_data
```

### Не хватает места на диске

```bash
# Проверить использование
du -sh volumes/*

# Очистить старые логи Docker
docker system prune -a

# Очистить старые бекапы (опционально)
find volumes/backup/ -mtime +30 -delete
```

---

## Roadmap

### В планах:

- [ ] Traefik для автоматического HTTPS
- [ ] Мониторинг (Prometheus + Grafana)
- [ ] Пример с GitLab/Gitea
- [ ] Пример с Bitwarden
- [ ] Offsite бекапы (rclone + S3)
- [ ] Ansible playbook для развёртывания

### Хотите добавить что-то?

Создайте issue или pull request!
