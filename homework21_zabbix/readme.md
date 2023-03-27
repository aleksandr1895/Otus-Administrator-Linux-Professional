Цель домашнего задания
----------------------

    Настройка мониторинга

Описание/Пошаговая инструкция выполнения домашнего задания:
-----------------------------------------------------------
```
    Настроить дашборд с 4-мя графиками

        память;
        процессор;
        диск;
        сеть.
```

### Установка Zabbix

1.Установите репозиторий Zabbix    
```
# rpm -Uvh https://repo.zabbix.com/zabbix/6.0/rhel/8/x86_64/zabbix-release-6.0-4.el8.noarch.rpm
# dnf clean all
```
2.Установите Zabbix сервер, веб-интерфейс и агент    
`` # dnf install zabbix-server-mysql zabbix-web-mysql zabbix-apache-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent``    

3.Создание базы данных    
Установите и запустите сервер базы данных.    
Выполните следующие комманды на хосте, где будет распологаться база данных.
```
# mysql -uroot -p
password
mysql> create database zabbix character set utf8mb4 collate utf8mb4_bin;
mysql> create user zabbix@localhost identified by 'password';
mysql> grant all privileges on zabbix.* to zabbix@localhost;
mysql> set global log_bin_trust_function_creators = 1;
mysql> quit;
```

4. На хосте Zabbix сервера импортируйте начальную схему и данные. Вам будет предложено ввести недавно созданный пароль.    
```
# zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p zabbix    
```
Выключите опцию log_bin_trust_function_creators после импорта схемы базы данных.    
```
# mysql -uroot -p
password
mysql> set global log_bin_trust_function_creators = 0;
mysql> quit;
```

5. Настройте базу данных для Zabbix сервера    
Отредактируйте файл /etc/zabbix/zabbix_server.conf    

    DBPassword=password    

6.  Запустите процессы Zabbix сервера и агента    
Запустите процессы Zabbix сервера и агента и настройте их запуск при загрузке ОС.    
```
# systemctl restart zabbix-server zabbix-agent httpd php-fpm
# systemctl enable zabbix-server zabbix-agent httpd php-fpm
```
Установка завершена открываем с помощью браузера http://192.168.11.80/zabbix    
Логин    Admin    
Пароль   zabbix    

Настраиваем Дашборд графики    
CPU
![Иллюстрация к проекту](https://github.com/aleksandr1895/Otus-Administrator-Linux-Professional/blob/master/homework21_zabbix/cpu_usage.png)
Memory
![Иллюстрация к проекту](https://github.com/aleksandr1895/Otus-Administrator-Linux-Professional/blob/master/homework21_zabbix/memory_usage.png)
Disk
![Иллюстрация к проекту](https://github.com/aleksandr1895/Otus-Administrator-Linux-Professional/blob/master/homework21_zabbix/disk_usage.png)
Net 
![Иллюстрация к проекту](https://github.com/aleksandr1895/Otus-Administrator-Linux-Professional/blob/master/homework21_zabbix/net_enp0s3.png)





 
