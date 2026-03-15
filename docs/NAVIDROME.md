# Navidrome - Музыкальный стриминг-сервер

## 📑 Оглавление

- [Что такое Navidrome](#что-такое-navidrome)
- [Быстрый старт](#быстрый-старт)
- [Настройка](#настройка)
- [Мобильные клиенты](#мобильные-клиенты)
- [Бекап](#бекап)
- [Troubleshooting](#troubleshooting)

---

## Что такое Navidrome

**Navidrome** - это self-hosted музыкальный стриминг-сервер с открытым исходным кодом.

### Возможности:
- 🎵 Стриминг музыки из вашей коллекции
- 📱 Поддержка Subsonic API (работает с множеством мобильных клиентов)
- 🎨 Автоматически загружает обложки альбомов и метаданные
- 👥 Поддержка нескольких пользователей
- 📊 Scrobbling в Last.fm
- ⚡ Быстрый и легковесный
- 🌐 Современный web-интерфейс

### Технические детали:
- **Образ**: `deluan/navidrome:0.60.3`
- **База данных**: SQLite (не требует PostgreSQL)
- **Порт**: 4533
- **Требования**: Музыкальная коллекция в форматах MP3, FLAC, OGG, M4A

---

## Быстрый старт

### 1. Подготовьте музыкальную библиотеку

Убедитесь, что ваша музыка организована в папках:

```
/home/user/Music/
├── Artist 1/
│   ├── Album 1/
│   │   ├── 01 - Track.mp3
│   │   └── cover.jpg
│   └── Album 2/
├── Artist 2/
└── ...
```

### 2. Обновите .env

```bash
nano .env
```

Добавьте/измените:

```bash
# Домен для Navidrome
NAVIDROME_DOMAIN=music.yourdomain.com

# Путь к музыкальной библиотеке на хосте
NAVIDROME_MUSIC_PATH=/home/user/Music
```

### 3. Настройте DNS (для доступа из интернета)

Создайте A-запись:

```
A    music    123.456.789.012
```

Где `123.456.789.012` - ваш внешний IP.

### 4. Запустите Navidrome

```bash
docker-compose up -d navidrome
```

### 5. Откройте в браузере

**Локально:**
```
http://localhost:4533
```

Или измените NAVIDROME_LOCAL_PORT в .env для другого порта.

**Из интернета (после настройки DNS):**
```
https://music.yourdomain.com
```

### 6. Создайте администратора

При первом входе Navidrome предложит создать учетную запись администратора.

---

## Настройка

### Переменные окружения

В `docker-compose.yml` можно настроить:

```yaml
environment:
  ND_SCANSCHEDULE: 1h              # Как часто сканировать библиотеку
  ND_LOGLEVEL: info                # Уровень логирования (debug, info, warn, error)
  ND_BASEURL: ""                   # Базовый URL (если за reverse proxy)
  ND_SESSIONTIMEOUT: 24h           # Время жизни сессии
  ND_ENABLETRANSCODINGCONFIG: true # Разрешить настройку транскодинга
```

### Сканирование библиотеки

**Автоматическое:**
- По расписанию (по умолчанию каждый час)

**Ручное:**
1. Зайдите в Settings (шестеренка)
2. Library → Start scan

### Добавление пользователей

1. Settings → Users
2. Create new user
3. Укажите имя, пароль, права доступа

---

## Мобильные клиенты

Navidrome совместим с любыми клиентами, поддерживающими Subsonic API.

### Android

**DSub** (рекомендуется)
- [Google Play](https://play.google.com/store/apps/details?id=github.daneren2005.dsub)
- Бесплатный, стабильный, много функций

**Ultrasonic**
- [Google Play](https://play.google.com/store/apps/details?id=org.moire.ultrasonic)
- Бесплатный, open-source

**Symfonium** (платный)
- [Google Play](https://play.google.com/store/apps/details?id=app.symfonik.music.player)
- Самый современный интерфейс

### iOS

**play:Sub**
- [App Store](https://apps.apple.com/app/play-sub/id955329386)
- Бесплатный

**substreamer**
- [App Store](https://apps.apple.com/app/substreamer/id1012991665)
- Платный

### Настройка клиента

**Параметры подключения:**
- **Server URL**: `https://music.yourdomain.com` (или локальный IP)
- **Username**: ваш логин
- **Password**: ваш пароль
- **Тип сервера**: Subsonic

**⚠️ Важно**: 
- Не добавляйте `/rest` в URL - клиенты добавят это автоматически
- Используйте HTTPS для безопасности (через Traefik)

---

## Бекап

### Что нужно бэкапить

1. **SQLite база данных**: `volumes/navidrome/data/navidrome.db`
2. **Кэш обложек/метаданных**: `volumes/navidrome/data/`
3. **Музыкальная библиотека**: обычно хранится отдельно и не требует бэкапа через Docker

### Автоматический бекап (TODO)

⚠️ **Пока не реализовано**

Планируется добавить контейнер для автоматического бэкапа:

```yaml
navidrome-backup:
  image: alpine:latest
  restart: always
  command: sh -c "while true; do 
    tar czf /backups/navidrome-$(date +%Y%m%d-%H%M%S).tar.gz -C /data . && 
    find /backups -name 'navidrome-*.tar.gz' -mtime +7 -delete && 
    sleep 86400; 
    done"
  volumes:
    - ./volumes/navidrome/data:/data:ro
    - ./volumes/backup/navidrome:/backups
```

### Ручной бекап

```bash
# Остановить Navidrome
docker-compose stop navidrome

# Создать архив
tar czf navidrome-backup-$(date +%Y%m%d).tar.gz volumes/navidrome/data/

# Запустить обратно
docker-compose start navidrome
```

### Восстановление

```bash
# Остановить Navidrome
docker-compose stop navidrome

# Удалить старые данные
rm -rf volumes/navidrome/data/*

# Восстановить из архива
tar xzf navidrome-backup-20260315.tar.gz -C volumes/navidrome/data/

# Запустить обратно
docker-compose start navidrome
```

---

## Расширенные настройки

### Last.fm Scrobbling

1. Settings → Last.fm
2. Link your Last.fm account
3. Музыка будет автоматически отправляться в Last.fm

### Транскодинг

Navidrome может конвертировать аудио на лету для экономии трафика.

**Настройка:**
1. Settings → Transcoding
2. Выберите битрейт для мобильных устройств
3. Включите транскодинг для медленных соединений

### Плейлисты

**Создание:**
1. Выберите треки
2. Add to playlist → Create new

**Экспорт:**
- Плейлисты хранятся в SQLite базе
- Можно экспортировать в форматах M3U, PLS

---

## Полезные ссылки

- [Официальная документация Navidrome](https://www.navidrome.org/docs/)
- [GitHub репозиторий](https://github.com/navidrome/navidrome)
- [Список совместимых клиентов](https://www.navidrome.org/docs/overview/#apps)
- [Subsonic API документация](http://www.subsonic.org/pages/api.jsp)

---

## Альтернативы

Если Navidrome вам не подходит, рассмотрите:

- **Airsonic-Advanced** - форк Subsonic
- **Funkwhale** - с социальными функциями
- **Jellyfin** - универсальный медиа-сервер (музыка + видео)
- **Plex** - коммерческое решение
