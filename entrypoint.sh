#!/bin/bash
set -e

echo "Starting TACACS+ NG Server..."

# Проверка наличия конфигурационного файла
if [ ! -f /opt/tac_plus-ng/etc/tac_plus-ng.cfg ]; then
    echo "ERROR: Configuration file /opt/tac_plus-ng/etc/tac_plus-ng.cfg not found!"
    echo "Please mount volume with configuration files to /opt/tac_plus-ng/etc"
    exit 1
fi

# Нличия файлов hosts и users
if [ ! -f /opt/tac_plus-ng/etc/tac_plus_hosts.cfg ]; then
    echo "WARNING: /opt/tac_plus-ng/etc/tac_plus_hosts.cfg not found!"
fi

if [ ! -f /opt/tac_plus-ng/etc/tac_plus_users.cfg ]; then
    echo "WARNING: /opt/tac_plus-ng/etc/tac_plus_users.cfg not found!"
fi

# Shadow
if [ ! -f /opt/tac_plus-ng/etc/shadow ]; then
    if [ -f /opt/tac_plus-ng/etc/shadow.txt ]; then
        cp /opt/tac_plus-ng/etc/shadow.txt /opt/tac_plus-ng/etc/shadow
        echo "Created shadow file from shadow.txt"
    else
        touch /opt/tac_plus-ng/etc/shadow
        echo "Created empty shadow file"
    fi
fi

chmod 600 /opt/tac_plus-ng/etc/shadow

echo "Configuration check passed. Starting TACACS+ NG..."
echo "Config file: /opt/tac_plus-ng/etc/tac_plus-ng.cfg"

# RUN tacacs
exec /opt/tac_plus-ng/sbin/tac_plus-ng /opt/tac_plus-ng/etc/tac_plus-ng.cfg
