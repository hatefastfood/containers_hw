#!/bin/bash

# Ставим пакеты lxc
apt update && apt install -y lxc lxc-astra

# Создаёем и запускаем контейнер (+ делаем паузу 5 секунд, чтобы контейнер успел запуститься перед выполнением след. команды)
lxc-create -t astralinux-se -n astra && lxc-start -n astra && echo "sleeping for 5 seconds…" && sleep 5 && echo "completed"

# Ставим zabbix+postrgesql в контейнер
lxc-attach -n astra -- apt install -y zabbix-server-pgsql zabbix-frontend-php php-pgsql acl

# Настраиваем работу с МКЦ, МРД (специфика Астры), даём необходимые права
lxc-attach -n astra -- bash -c "pdpl-user -l 0:0 -i 63 postgres && pdpl-user -l 0:0 zabbix"
lxc-attach -n astra -- bash -c "setfacl -d -m u:postgres:r /etc/parsec/{macdb,capdb} && setfacl -R -m u:postgres:r /etc/parsec/{macdb,capdb} && setfacl -m u:postgres:rx /etc/parsec/{macdb,capdb}"
lxc-attach -n astra -- bash -c "sed -i 's/^\s*#\?\s*AstraMode.*/AstraMode off/' /etc/apache2/apache2.conf && systemctl reload apache2"

# Настройка PostgreSQL
lxc-attach -n astra -- bash -c "sed -i '/# TYPE  DATABASE        USER            ADDRESS                 METHOD/alocal   zabbix          zabbix                                  trust' /etc/postgresql/*/main/pg_hba.conf && sed -i '/# IPv4 local connections:/ahost    zabbix          zabbix          127.0.0.1/32            trust' /etc/postgresql/*/main/pg_hba.conf && systemctl restart postgresql"

# Создаем пользователя и базу zabbix
lxc-attach -n astra -- sudo -u postgres psql -c "CREATE DATABASE ZABBIX;"
lxc-attach -n astra -- sudo -u postgres psql -c "CREATE USER zabbix WITH ENCRYPTED PASSWORD '12345678';"
lxc-attach -n astra -- sudo -u postgres psql -c "GRANT ALL ON DATABASE zabbix to zabbix;"

# Импорт шаблона БД zabbix
lxc-attach -n astra -- bash -c "zcat /usr/share/zabbix-server-pgsql/{schema,images,data}.sql.gz | psql -h localhost zabbix zabbix && a2enconf zabbix-frontend-php && systemctl reload apache2"

# Информация о контейнере
echo "Информация о контейнере:"
lxc-ls -f | grep astra
