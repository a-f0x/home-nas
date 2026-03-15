# qBittorrent - Торрент-клиент

## 📑 Оглавление

- [Что такое qBittorrent](#что-такое-qbittorrent)
- [Быстрый старт](#быстрый-старт)
- [Настройка](#настройка)
- [Пробрасывание портов](#пробрасывание-портов)
- [Troubleshooting](#troubleshooting)

---

## Что такое qBittorrent

**qBittorrent** - это мощный и легковесный торрент-клиент с открытым исходным кодом.

### Возможности:
- 🌐 Веб-интерфейс для управления
- 🔍 Встроенный поиск по торрент-трекерам
- 📊 RSS подписки
- ⚡ Последовательное скачивание (для просмотра видео во время загрузки)
- 🎯 Управление приоритетами файлов
- 🔒 Поддержка шифрования
- 📱 Совместим с мобильными приложениями

### Технические детали:
- **Образ**: `qbittorrentofficial/qbittorrent-nox:5.1.4-2`
- **База данных**: Не требуется (настройки в файлах)
- **Веб-интерфейс**: Настраивается через `QBITTORRENT_LOCAL_PORT` (по умолчанию 8082)
- **Сетевой режим**: `host` (прямой доступ к сети хоста)

---

## Быстрый старт

### 1. Подготовьте папку для загрузок

Создайте папку на хосте для скачанных файлов:

```bash
mkdir -p /home/user/Downloads/torrents
```

### 2. Обновите .env

```bash
nano .env
```

Добавьте/измените:

```bash
# qBittorrent
QBITTORRENT_LOCAL_PORT=8082
QBITTORRENT_DOWNLOADS_PATH=/home/user/Downloads/torrents
```

### 3. Пробросьте порт на роутере

**Важно!** Для работы торрентов нужно пробросить порт 6881:

```
Внешний порт → Внутренний IP:Порт

6881 (TCP) → 192.168.x.x:6881
6881 (UDP) → 192.168.x.x:6881
```

Где `192.168.x.x` - локальный IP вашего сервера.

### 4. Запустите qBittorrent

```bash
docker-compose up -d qbittorrent
```

### 5. Откройте веб-интерфейс

**Локально:**
```
http://localhost:8082
```

**Из локальной сети:**
```
http://192.168.x.x:8082
```

### 6. Первый вход

При первом запуске смотрите временный пароль в логах:

```bash
docker logs cloud-qbittorrent-1 | grep password
```

Вы увидите что-то вроде:
```
The WebUI administrator password was not set. A temporary password is provided for this session: AbCdEfGhI
```

**Логин:** `admin`  
**Пароль:** временный пароль из логов

⚠️ **Сразу смените пароль** после входа: Settings → Web UI → Authentication

---

## Настройка

### Основные настройки

После входа в веб-интерфейс:

1. **Settings → Downloads**
   - Default Save Path: `/downloads` (уже настроен)
   - Temp folder: `/downloads/temp`

2. **Settings → Connection**
   - Listening Port: `6881` (по умолчанию)
   - ✅ Use UPnP / NAT-PMP (если роутер поддерживает)

3. **Settings → BitTorrent**
   - ✅ Enable DHT
   - ✅ Enable PeX
   - ✅ Enable Local Peer Discovery

4. **Settings → Web UI**
   - Смените пароль!
   - IP address: `*` (слушать на всех интерфейсах)
   - Port: `8082` (или ваш QBITTORRENT_LOCAL_PORT)

### Ограничение скорости

Если не хотите забивать весь канал:

1. Settings → Speed
   - Global Rate Limits:
     - Upload: например, 5000 KB/s
     - Download: например, 10000 KB/s
   - Alternative Rate Limits (можно переключаться):
     - Upload: например, 1000 KB/s
     - Download: например, 5000 KB/s

### Расписание скорости

Settings → Speed → Schedule:
- Можно настроить альтернативные лимиты по расписанию
- Например: ночью - полная скорость, днём - ограничена

---

## Пробрасывание портов

### Порт 6881 (торренты)

**⚠️ ОБЯЗАТЕЛЬНО** пробросьте на роутере для нормальной работы:

- **TCP** 6881 → 192.168.x.x:6881
- **UDP** 6881 → 192.168.x.x:6881

Где `192.168.x.x` - IP вашего сервера.

### Проверка открытых портов

1. В qBittorrent: Settings → Connection
2. Нажмите кнопку **"Test"** рядом с Listening Port
3. Должно быть: ✅ "Port is open"

Или проверьте онлайн:
- https://www.yougetsignal.com/tools/open-ports/
- Введите порт 6881

### Если порт закрыт

**Симптомы:**
- Медленная скорость
- Мало пиров/сидов
- Много торрентов в состоянии "Stalled"

**Решение:**
1. Проверьте настройки роутера (Port Forwarding)
2. Проверьте файрвол на сервере:
   ```bash
   sudo ufw allow 6881/tcp
   sudo ufw allow 6881/udp
   ```
3. Перезапустите контейнер:
   ```bash
   docker-compose restart qbittorrent
   ```

---

## Использование

### Добавление торрентов

**Способ 1: Через файл**
1. Нажмите ➕ (Add Torrent)
2. Browse → выберите .torrent файл
3. Выберите папку сохранения
4. OK

**Способ 2: Через magnet-ссылку**
1. Скопируйте magnet-ссылку
2. Нажмите ➕ (Add Torrent)
3. Вставьте magnet-ссылку
4. OK

**Способ 3: Через URL**
1. Нажмите ➕ (Add Torrent)
2. Вставьте прямую ссылку на .torrent файл
3. OK

### Управление торрентами

**Пауза/Возобновление:**
- ⏸️ Пауза: ПКМ → Pause
- ▶️ Возобновить: ПКМ → Resume

**Приоритеты:**
- ПКМ → Set Priority → High/Normal/Low

**Последовательное скачивание:**
- ПКМ → Download in sequential order
- Полезно для просмотра видео во время загрузки

**Выбор файлов:**
- Двойной клик на торренте
- Снимите галочки с ненужных файлов

### RSS подписки

1. View → RSS Reader
2. New subscription
3. Добавьте RSS ленту торрент-трекера
4. Настройте автоматическую загрузку:
   - New rule
   - Задайте фильтры (например, по названию)
   - Торренты будут загружаться автоматически

---

## Безопасность

### Рекомендации

1. **Смените пароль** сразу после первого входа
2. **НЕ пробрасывайте порт 8082** на роутере - только для локальной сети
3. **Ограничьте скорость** если не хотите забить весь канал

---

## Troubleshooting

### Веб-интерфейс не открывается

**Проблема**: Страница не загружается

**Решение**:

1. **Проверьте, что контейнер запущен:**
   ```bash
   docker ps | grep qbittorrent
   ```

2. **Проверьте логи:**
   ```bash
   docker logs cloud-qbittorrent-1
   ```

3. **Проверьте порт:**
   ```bash
   sudo ss -tlnp | grep 8082
   ```

4. **Перезапустите:**
   ```bash
   docker-compose restart qbittorrent
   ```

### Медленная скорость

**Проблема**: Торренты качаются медленно

**Решение**:

1. **Проверьте открытость порта 6881** (см. выше)

2. **Проверьте количество соединений:**
   - Settings → Connection
   - Max connections: 500 (для домашнего сервера)
   - Max connections per torrent: 100

3. **Отключите ограничение скорости:**
   - Settings → Speed
   - Проверьте лимиты

4. **Проверьте сиды:**
   - Если у торрента мало сидов - будет медленно
   - Смотрите колонку "Seeds" в списке торрентов

### Торренты в статусе "Stalled"

**Проблема**: Торренты не качаются, статус "Stalled"

**Решение**:

1. **Порт закрыт** - откройте 6881 на роутере
2. **Нет сидов** - подождите или найдите другой торрент
3. **Проблемы с трекером** - обновите трекеры:
   - ПКМ на торренте → Edit trackers
   - Добавьте публичные трекеры

### Нет места на диске

**Проблема**: "No space left on device"

**Решение**:

1. **Проверьте место:**
   ```bash
   df -h
   ```

2. **Очистите место** или смените папку загрузок в .env

3. **Удалите старые торренты:**
   - ПКМ → Delete → Delete files

### Высокая нагрузка на диск

**Проблема**: Диск сильно нагружен

**Решение**:

Settings → Advanced → Disk cache:
- Disk cache: 64 MB или больше
- Disk cache expiry interval: 120 s

---

## Доступ с мобильного

### Android

**qBittorrent Client** (рекомендуется)
- [Google Play](https://play.google.com/store/apps/details?id=com.lgallardo.qbittorrentclient)
- Бесплатный, удобный

**Transdrone**
- [Google Play](https://play.google.com/store/apps/details?id=org.transdroid.full)
- Поддерживает много торрент-клиентов

### iOS

**qBitController**
- [App Store](https://apps.apple.com/app/qbitcontroller/id1348530186)

### Настройка мобильного клиента

- **Server URL**: `http://192.168.x.x:8082`
- **Username**: `admin`
- **Password**: ваш пароль
- **Type**: qBittorrent

---

## Полезные ссылки

- [Официальная документация qBittorrent](https://github.com/qbittorrent/qBittorrent/wiki)
- [qBittorrent WebUI API](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1))
- [Список публичных трекеров](https://github.com/ngosang/trackerslist)

---

## Альтернативы

Если qBittorrent вам не подходит:

- **Transmission** - более простой и легковесный
- **Deluge** - с системой плагинов
- **rTorrent + Flood** - для продвинутых пользователей
- **Aria2** - консольный, очень быстрый
