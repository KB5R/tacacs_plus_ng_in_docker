# TACACS+ NG в Docker

Отказоустойчивый TACACS+ сервер на базе ALT Linux Sisyphus в Docker контейнере.

## Описание

Этот проект позволяет развернуть TACACS+ NG сервер в Docker контейнере с возможностью:
- Переноса на изолированные сети без интернета
- Настройки отказоустойчивости через rsync между серверами
- Гибкой настройки аутентификации (local, LDAP, AD, FreeIPA)

## Структура проекта

```
.
├── Dockerfile              # Сборка образа на базе ALT Linux
├── docker-compose.yml      # Конфигурация для запуска контейнера
├── entrypoint.sh          # Скрипт запуска TACACS+
├── files/                 # Файлы для сборки
│   └── DEVEL.202310061820.tar.bz2
├── volume/                # Конфигурационные файлы (монтируются в контейнер)
│   ├── tac_plus-ng.cfg           # Главный конфиг
│   ├── tac_plus_hosts.cfg        # Настройки хостов
│   ├── tac_plus_users.cfg        # Пользователи и профили
│   └── shadow.txt                # Пароли пользователей
└── logs/                  # Логи TACACS+ (создаются автоматически)
```

## Требования

- Docker
- docker-compose (опционально)
- Свободный порт 49 (TCP)

## Быстрый старт

### 1. Сборка образа

```bash
docker build -t tacacs-ng:latest .
```

Или с sudo (если пользователь не в группе docker):
```bash
sudo docker build -t tacacs-ng:latest .
```

### 2. Запуск контейнера

Используя docker-compose:
```bash
docker-compose up -d
```

Или напрямую через docker:
```bash
docker run -d \
  --name tacacs-ng \
  --restart always \
  --network host \
  -v ./volume:/opt/tac_plus-ng/etc \
  -v ./logs:/var/log/tac_plus-ng \
  tacacs-ng:latest
```

### 3. Проверка работы

Проверить статус контейнера:
```bash
docker ps
```

Проверить что порт 49 слушается:
```bash
netstat -tuln | grep :49
# или
ss -tuln | grep :49
```

Просмотр логов:
```bash
docker logs tacacs-ng
```

Логи TACACS+ находятся в:
```bash
./logs/authz/   # Логи авторизации
./logs/authc/   # Логи аутентификации
./logs/acct/    # Логи учета
```

## Управление контейнером

### Остановка
```bash
docker-compose down
# или
docker stop tacacs-ng
```

### Перезапуск
```bash
docker-compose restart
# или
docker restart tacacs-ng
```

### Удаление контейнера
```bash
docker-compose down
docker rm tacacs-ng
```

## Настройка конфигурации

Все конфигурационные файлы находятся в директории `./volume/`

### Главный конфиг: tac_plus-ng.cfg

**ВАЖНО:** Параметр `background = no` обязателен для работы в Docker!

```
id = spawnd {
    listen = {
        port = 49
        address = 0.0.0.0
    }
    spawn = {
        instances min = 1
        instances max = 10
    }
    background = no    # Обязательно!
}
```

### Файлы для синхронизации между серверами

При настройке отказоустойчивости синхронизируются:
- `tac_plus_hosts.cfg` - настройки сетевого оборудования
- `tac_plus_users.cfg` - пользователи и профили доступа
- `shadow.txt` - пароли пользователей

Главный конфиг `tac_plus-ng.cfg` **НЕ синхронизируется** (он уникален для каждого сервера).

### Редактирование конфигов

После изменения любого конфига необходимо перезапустить контейнер:
```bash
docker-compose restart
```

## Отказоустойчивость (Active-Active)

Для настройки отказоустойчивости разверните контейнер на двух физических серверах.

### Архитектура

```
┌─────────────────┐         ┌─────────────────┐
│   Server 1      │         │   Server 2      │
│ (192.168.1.10)  │ ◄─────► │ (192.168.1.11)  │
│                 │  rsync  │                 │
│ tacacs-ng:49    │         │ tacacs-ng:49    │
└─────────────────┘         └─────────────────┘
         │                           │
         └───────────┬───────────────┘
                     │
              ┌──────▼──────┐
              │  Оборудование │
              │  (использует  │
              │  оба сервера) │
              └──────────────┘
```

### Настройка rsync синхронизации

На **primary сервере** создайте скрипт синхронизации:

```bash
#!/bin/bash
# sync-to-secondary.sh

REMOTE_USER="user"
REMOTE_HOST="192.168.1.11"
REMOTE_PATH="/path/to/volume"
LOCAL_PATH="/path/to/volume"

rsync -avz \
  "$LOCAL_PATH/tac_plus_hosts.cfg" \
  "$LOCAL_PATH/tac_plus_users.cfg" \
  "$LOCAL_PATH/shadow.txt" \
  "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"

# Перезапуск TACACS+ на secondary после синхронизации
ssh "$REMOTE_USER@$REMOTE_HOST" "docker restart tacacs-ng"
```

Добавьте в crontab для автоматической синхронизации:
```bash
# Синхронизация каждые 5 минут
*/5 * * * * /path/to/sync-to-secondary.sh
```

### Настройка на оборудовании

В конфигурации оборудования укажите оба TACACS+ сервера:

**Cisco:**
```
tacacs-server host 192.168.1.10 key YOUR_SECRET_KEY
tacacs-server host 192.168.1.11 key YOUR_SECRET_KEY
```

**Huawei:**
```
hwtacacs-server template default
  hwtacacs-server authentication 192.168.1.10
  hwtacacs-server authentication 192.168.1.11
  hwtacacs-server shared-key cipher YOUR_SECRET_KEY
```

## Перенос на изолированную сеть

### 1. На машине с интернетом

Экспортируйте собранный образ:
```bash
docker save tacacs-ng:latest -o tacacs-ng-image.tar
```

Создайте архив для переноса:
```bash
tar -czf tacacs-deploy.tar.gz \
  tacacs-ng-image.tar \
  docker-compose.yml \
  volume/
```

### 2. На изолированной машине

Скопируйте `tacacs-deploy.tar.gz` и распакуйте:
```bash
tar -xzf tacacs-deploy.tar.gz
```

Загрузите образ:
```bash
docker load -i tacacs-ng-image.tar
```

Проверьте что образ загружен:
```bash
docker images | grep tacacs-ng
```

Запустите контейнер:
```bash
docker-compose up -d
```

## Безопасность

1. **Файл shadow** - содержит хеши паролей, права должны быть 600
2. **Ключ TACACS+** - задается в `tac_plus_hosts.cfg` параметром `key`
3. **Сеть** - рекомендуется ограничить доступ к порту 49 через firewall

Пример iptables:
```bash
# Разрешить доступ только с подсети оборудования
iptables -A INPUT -p tcp --dport 49 -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport 49 -j DROP
```

## Troubleshooting

### Контейнер постоянно перезапускается

Проверьте логи:
```bash
docker logs tacacs-ng
```

Частая причина: `background = yes` в конфиге. Должно быть `background = no`.

### Порт 49 не слушается

Проверьте что контейнер запущен:
```bash
docker ps | grep tacacs-ng
```

Проверьте конфигурацию сети:
```bash
docker inspect tacacs-ng | grep -i network
```

### Ошибки аутентификации

Проверьте логи TACACS+:
```bash
tail -f ./logs/authc/$(date +%Y/%m/%d).log
tail -f ./logs/authz/$(date +%Y/%m/%d).log
```

Проверьте что ключ на оборудовании совпадает с ключом в `tac_plus_hosts.cfg`.

## Лицензия

MIT License

## Автор

Maintainer: Popkov MK
