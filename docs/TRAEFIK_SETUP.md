# Настройка Traefik и HTTPS

Инструкция по настройке доступа к приложениям через HTTPS с автоматическими сертификатами.

## 📑 Оглавление

- [Что такое Traefik](#что-такое-traefik)
- [Предварительные требования](#предварительные-требования)
- [Быстрый старт](#быстрый-старт)
- [Настройка DNS](#настройка-dns)
- [Настройка роутера](#настройка-роутера)
- [Настройка email для Let's Encrypt](#настройка-email-для-lets-encrypt)
- [Проверка работы](#проверка-работы)
- [Traefik Dashboard](#traefik-dashboard)
- [Добавление новых приложений](#добавление-новых-приложений)
- [Troubleshooting](#troubleshooting)

---

## Что такое Traefik

**Traefik** - это современный reverse proxy, который:

- 🔒 Автоматически получает SSL сертификаты от Let's Encrypt
- 🔄 Автоматически обновляет сертификаты
- 🐳 Автоматически обнаруживает Docker контейнеры
- 📊 Имеет встроенный dashboard для мониторинга
- ↗️ Делает HTTP → HTTPS редирект

---

## Предварительные требования

### 1. Доменное имя

У вас должен быть домен (в вашем случае: `ton618.ru`)

### 2. Статический IP или DDNS

- **Статический IP**: Лучший вариант
- **Динамический IP**: Используйте DDNS сервис (No-IP, DuckDNS, Cloudflare)

### 3. Открытые порты на роутере

Нужно пробросить порты на ваш сервер:
- **80** (HTTP) - для получения сертификатов Let's Encrypt
- **443** (HTTPS) - для HTTPS трафика

### 4. Email

Для уведомлений от Let's Encrypt о истечении сертификатов

---

## Быстрый старт

### Шаг 1: Обновите `.env`

```bash
nano .env
```

**Измените:**

```bash
# Ваш домен
DOMAIN=ton618.ru
NEXTCLOUD_DOMAIN=home.ton618.ru

# Email для Let's Encrypt уведомлений (в traefik.yml)
```

### Шаг 2: Обновите email в Traefik конфиге

```bash
nano docker/traefik/traefik.yml
```

**Найдите и измените:**

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com  # <-- ИЗМЕНИТЕ НА ВАШ EMAIL!
```

### Шаг 3: Настройте DNS (см. следующий раздел)

### Шаг 4: Настройте роутер (см. следующий раздел)

### Шаг 5: Запустите

```bash
# Остановите старые контейнеры
docker-compose down

# Запустите с Traefik
docker-compose up -d

# Проверьте логи
docker-compose logs -f traefik
```

---

## Настройка DNS

Создайте **A-запись** для вашего домена, указывающую на **внешний IP** вашего роутера.

### Узнайте ваш внешний IP:

```bash
curl ifconfig.me
```

### Настройте DNS записи:

Зайдите в панель управления вашего регистратора доменов и добавьте:

```
Тип    Имя     Значение           TTL
A      home    123.456.789.012    3600
```

Где `123.456.789.012` - ваш внешний IP.

**Результат:** `home.ton618.ru` будет указывать на ваш сервер.

### Проверка DNS:

```bash
# Проверить, резолвится ли домен
nslookup home.ton618.ru

# Или
dig home.ton618.ru
```

⏰ **Важно:** DNS изменения могут занять от 5 минут до 24 часов.

---

## Настройка роутера

### Проброс портов (Port Forwarding):

Зайдите в веб-интерфейс вашего роутера и настройте проброс портов:

```
Внешний порт → Внутренний IP:Порт

80  → 192.168.1.100:80    (HTTP для Let's Encrypt)
443 → 192.168.1.100:443   (HTTPS для приложений)
```

Где `192.168.1.100` - локальный IP вашего сервера.

### Узнать локальный IP сервера:

```bash
hostname -I
```

### Статический IP в локальной сети:

Рекомендую назначить серверу статический локальный IP:
- В настройках роутера (DHCP Reservation)
- Или в настройках сети на сервере

---

## Настройка email для Let's Encrypt

**Обязательно** измените email в конфиге Traefik:

```bash
nano docker/traefik/traefik.yml
```

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: your-real-email@gmail.com  # <-- ВАШ EMAIL
      storage: /acme.json
      httpChallenge:
        entryPoint: web
```

**Зачем нужен email:**
- Уведомления об истечении сертификатов
- Важные сообщения от Let's Encrypt
- Восстановление доступа

---

## Проверка работы

### 1. Проверьте, что Traefik запустился:

```bash
docker-compose ps traefik
```

Должен быть статус `Up`.

### 2. Проверьте логи Traefik:

```bash
docker-compose logs -f traefik
```

**Хорошие признаки:**
```
time="..." level=info msg="Configuration loaded from file: /traefik.yml"
time="..." level=info msg="Traefik version 3.2"
```

**Ошибки Let's Encrypt** (если есть):
```
level=error msg="Unable to obtain ACME certificate"
```

### 3. Откройте в браузере:

**Из интернета (после настройки DNS и роутера):**
```
https://home.ton618.ru
```

**Первый запуск может занять 1-2 минуты** для получения сертификата.

**Dashboard (только локально):**
```bash
# Узнайте IP сервера
hostname -I | awk '{print $1}'

# Откройте dashboard
http://192.168.x.x:8080
```

Логин: `admin` / Пароль: `changeme`

### 4. Проверьте сертификат:

В браузере кликните на замочек → сертификат должен быть от Let's Encrypt.

---

## Traefik Dashboard

Dashboard доступен **только из локальной сети** по адресу:

```
http://192.168.x.x:8080
```

Где `192.168.x.x` - локальный IP вашего сервера. Порт можно изменить через TRAEFIK_DASHBOARD_PORT в .env.

**Узнать IP сервера:**
```bash
hostname -I | awk '{print $1}'
```

**Логин:** `admin`  
**Пароль:** `changeme` (по умолчанию)

⚠️ **Важно:** Dashboard НЕ доступен из интернета и НЕ требует проброса порта 8080 на роутере. Это сделано для безопасности.

### Изменить пароль для dashboard:

```bash
# Сгенерировать хеш пароля
echo $(htpasswd -nb admin your-new-password) | sed -e s/\\$/\\$\\$/g

# Или онлайн: https://hostingcanada.org/htpasswd-generator/
```

Скопируйте результат и вставьте в `.env`:

```bash
TRAEFIK_DASHBOARD_AUTH=admin:$$apr1$$...
```

Перезапустите:

```bash
docker-compose up -d traefik
```

### Отключить dashboard (для production):

Если dashboard вообще не нужен, в `docker-compose.yml` закомментируйте:

```yaml
traefik:
  ports:
    # - "8080:8080"   # <-- закомментировать
```

И удалите все labels с `dashboard` в секции traefik.

---

## Добавление новых приложений

Когда добавляете новое приложение (например, WordPress):

### 1. Добавьте DNS запись:

```
A    blog    123.456.789.012
```

### 2. Добавьте labels в docker-compose.yml:

```yaml
wordpress:
  image: wordpress
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.wordpress.rule=Host(`blog.ton618.ru`)"
    - "traefik.http.routers.wordpress.entrypoints=websecure"
    - "traefik.http.routers.wordpress.tls.certresolver=letsencrypt"
    - "traefik.http.services.wordpress.loadbalancer.server.port=80"
```

### 3. Перезапустите:

```bash
docker-compose up -d
```

**Готово!** Traefik автоматически:
- Обнаружит новый контейнер
- Получит SSL сертификат
- Настроит роутинг

---

## Troubleshooting

### Сертификат не получается

**Проблема:** Traefik не может получить сертификат от Let's Encrypt

**Проверьте:**

1. **Порт 80 открыт:**
   ```bash
   # На сервере
   sudo netstat -tulpn | grep :80
   
   # Извне (с другого компьютера)
   telnet your-domain.com 80
   ```

2. **DNS резолвится:**
   ```bash
   nslookup home.ton618.ru
   ```

3. **Логи Traefik:**
   ```bash
   docker-compose logs traefik | grep -i acme
   docker-compose logs traefik | grep -i error
   ```

4. **Права на acme.json:**
   ```bash
   ls -la volumes/traefik/acme.json
   # Должно быть: -rw------- (600)
   ```

**Исправить права:**
```bash
chmod 600 volumes/traefik/acme.json
docker-compose restart traefik
```

### HTTP вместо HTTPS

**Проблема:** Браузер открывает HTTP, а не HTTPS

**Решение:** Используйте прямую ссылку с `https://`

Traefik настроен на автоматический редирект HTTP → HTTPS, но при первом обращении может понадобиться явно указать протокол.

---

### Dashboard недоступен

**Проблема:** Dashboard не открывается

**Решение:** Dashboard доступен **только из локальной сети**

```bash
# Узнайте IP вашего сервера
hostname -I | awk '{print $1}'

# Откройте в браузере (с того же компьютера в локальной сети):
http://192.168.x.x:8080
```

Где `192.168.x.x` - локальный IP сервера.

**Проверьте:**

1. **Контейнер traefik запущен:**
   ```bash
   docker-compose ps traefik
   ```

2. **Порт 8080 слушается:**
   ```bash
   sudo netstat -tulpn | grep :8080
   ```

3. **Логи:**
   ```bash
   docker-compose logs traefik | grep dashboard
   ```

⚠️ **Важно:** 
- Dashboard НЕ доступен из интернета
- НЕ нужен проброс порта 8080 на роутере
- Доступ только из локальной сети (для безопасности)

---

### "Too many certificates" от Let's Encrypt

**Проблема:** Let's Encrypt имеет лимиты (5 сертификатов в неделю для одного домена)

**Решение:**

1. **Используйте staging сервер** для тестов:

   В `docker/traefik/traefik.yml`:
   ```yaml
   certificatesResolvers:
     letsencrypt:
       acme:
         caServer: "https://acme-staging-v02.api.letsencrypt.org/directory"
   ```

2. После тестов уберите эту строку для production сертификатов

3. Удалите старые сертификаты:
   ```bash
   rm volumes/traefik/acme.json
   touch volumes/traefik/acme.json
   chmod 600 volumes/traefik/acme.json
   docker-compose restart traefik
   ```
 
## Полезные ссылки

- [Официальная документация Traefik](https://doc.traefik.io/traefik/)
- [Let's Encrypt лимиты](https://letsencrypt.org/docs/rate-limits/)
- [Traefik + Docker](https://doc.traefik.io/traefik/providers/docker/)
- [Проверить SSL сертификат](https://www.ssllabs.com/ssltest/)
