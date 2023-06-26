Цель Домашнего задания
----------------------
Настроить репликацию mysql    

Описание/Пошаговая инструкция выполнения домашнего задания:
-----------------------------------------------------------
```
Для выполнения домашнего задания используйте методичку
https://drive.google.com/file/d/139irfqsbAxNMjVcStUN49kN7MXAJr_z9/view?usp=share_link
Что нужно сделать?
В материалах приложены ссылки на вагрант для репликации и дамп базы bet.dmp
Базу развернуть на мастере и настроить так, чтобы реплицировались таблицы:
| bookmaker |
| competition |
| market |
| odds |
| outcome

Настроить GTID репликацию
x
варианты которые принимаются к сдаче
рабочий вагрантафайл
скрины или логи SHOW TABLES
```

### Установка Mysql
Ставим percona-server-57 на master и slave по инструкции. В целом она сводится к следующему:    
**yum install http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm -y**    
**yum install Percona-Server-server-57 -y**    

Настройка Mysql
---------------
По умолчанию Percona хранит файлы в таком виде:    
Основной конфиг в ``/etc/my.cnf``    
Так же инклудится директория ``/etc/my.cnf.d/`` - куда мы и будем складывать наши конфиги.    
Дата файлы в ``/var/lib/mysql``    

MySQL Репликация
----------------
Копируем конфиги из ``/vagrant/conf.d в /etc/my.cnf.d/``    
``cp /vagrant/conf/conf.d/* /etc/my.cnf.d/``    
После этого можно запустить службу:    
``systemctl start mysql``    

При установке Percona автоматически генерирует пароль для пользователя root и кладет его в файл ``/var/log/mysqld.log:``    
``cat /var/log/mysqld.log | grep 'root@localhost:' | awk '{print $11}'``    
``:we8Ocf6:z)j``

Подключаемся к mysql и меняем пароль ядра доступа к полному функционалу:    
```
mysql -uroot -p':we8Ocf6:z)j'
mysql > ALTER USER USER() IDENTIFIED BY ':we8Ocf6:z)j';
```

MySQL Репликация
-----------------
Репликацию будем настраивать с использованием GTID.    
Следует обратить внимание, что атрибут ``server-id`` на мастер-сервере должен обязательно отличаться от ``server-id`` слейв-сервера.     Проверить какая переменная установлена в текущий момент можно следующим образом:    
``` 
mysql> SELECT @@server_id;
+---------------------+
| @@server_id |
+---------------------+
| 1 |
+---------------------+
```

Убеждаемся что GTID включен:
```
mysql> SHOW VARIABLES LIKE 'gtid_mode';
+-----------------------+---------+
| Variable_name | Value |
+-----------------------+--------+
| gtid_mode | ON |
+-----------------------+--------+
```


Создадим тестовую базу bet и загрузим в нее дамп и проверим:    
```
mysql> CREATE DATABASE bet;
Query OK, 1 row affected (0.00 sec)
[root@otuslinux ~] mysql -uroot -p -D bet < /vagrant/bet.dmp
mysql> USE bet;
mysql> SHOW TABLES;
+-----------------------------+
| Tables_in_bet |
+-----------------------------+
| bookmaker |
| competition |
| events_on_demand |
| market |
| odds |
| outcome |
| v_same_event |
+------------------------------+
```

Создадим пользователя для репликации и даем ему права на эту самую репликацию:    
```
mysql> CREATE USER 'repl'@'%' IDENTIFIED BY '!OtusLinux2018';
mysql> SELECT user,host FROM mysql.user where user='repl';
+------+-----------+
| user | host |
+------+-----------+
| repl | % |
+------+-----------+
mysql> GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%' IDENTIFIED BY '!OtusLinux2018';
```

Дампим базу для последующего залива на слэйв и игнорируем таблицу по заданию:    

```
[root@otuslinux ~] mysqldump --all-databases --triggers --routines --master-data
--ignore-table=bet.events_on_demand --ignore-table=bet.v_same_event -uroot -p > master.sql
```
На этом настройка Master-а завершена. Файл дампа нужно залить на слейв.    


SLAVE
-------
```
mysql -uroot -p'bAbnQNsp!4,w'
mysql > ALTER USER USER() IDENTIFIED BY 'bAbnQNsp!4,w';
```
Так же точно копируем конфиги из ``/vagrant/conf.d в /etc/my.cnf.d/``    
``cp /vagrant/conf/conf.d/* /etc/my.cnf.d/``    

Правим в ``/etc/my.cnf.d/01-basics.cnf директиву server-id = 2``

```
mysql> SELECT @@server_id;
+---------------------+
| @@server_id |
+---------------------+
| 2 |
+---------------------+
```
MySQL Репликация

Раскомментируем в ``/etc/my.cnf.d/05-binlog.cnf строки:``    
```
#replicate-ignore-table=bet.events_on_demand
#replicate-ignore-table=bet.v_same_event
```
Таким образом указываем таблицы которые будут игнорироваться при репликации    


Заливаем дамп мастера и убеждаемся что база есть и она без лишних таблиц:    
```
mysql> SOURCE /mnt/master.sql
mysql> SHOW DATABASES LIKE 'bet';
+-----------------------+
| Database (bet) |
+-----------------------+
| bet |
+-----------------------+
mysql> USE bet;
mysql> SHOW TABLES;
+---------------------+
| Tables_in_bet |
+---------------------+
| bookmaker |
| competition |
| market |
| odds |
| outcome |
+---------------------+ # видим что таблиц v_same_event и events_on_demand нет
```

Ну и собственно подключаем и запускаем слейвы:    
```
mysql> CHANGE MASTER TO MASTER_HOST = "192.168.11.150", MASTER_PORT = 3306,
MASTER_USER = "repl", MASTER_PASSWORD = "!OtusLinux2018", MASTER_AUTO_POSITION = 1;
mysql> START SLAVE;
mysql> SHOW SLAVE STATUS\G

*************************** 1. row ***************************
Slave_IO_State: Waiting for master to send event
                  Master_Host: 192.168.11.150
                  Master_User: repl
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000002
          Read_Master_Log_Pos: 119568
               Relay_Log_File: slave-relay-bin.000002
                Relay_Log_Pos: 627
        Relay_Master_Log_File: mysql-bin.000002
             Slave_IO_Running: Yes
            Slave_SQL_Running: No
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: bet.events_on_demand,bet.v_same_event
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table: 
```

Видно что репликациā работает, gtid работает и игнорятся таблички по заданию:
```
eplicate_Ignore_Server_Ids: 
             Master_Server_Id: 1
                  Master_UUID: 7f20aac6-1408-11ee-a93f-5254004d77d3
             Master_Info_File: /var/lib/mysql/master.info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: 
           Master_Retry_Count: 86400
                  Master_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 
               Master_SSL_Crl: 
           Master_SSL_Crlpath: 
           Retrieved_Gtid_Set: 7f20aac6-1408-11ee-a93f-5254004d77d3:1-39
            Executed_Gtid_Set: 405367cc-1409-11ee-abe3-5254004d77d3:1,
7f20aac6-1408-11ee-a93f-5254004d77d3:1
                Auto_Position: 1
         Replicate_Rewrite_DB: 
                 Channel_Name: 
           Master_TLS_Version: 
1 row in set (0.00 sec)
```


Проверим репликацию в действии. На мастере:    
```
mysql> USE bet;
mysql> INSERT INTO bookmaker (id,bookmaker_name) VALUES(1,'1xbet');
mysql> SELECT * FROM bookmaker;
+----+---------------------------+
| id | bookmaker_name |
+----+---------------------------+
| 1 | 1xbet |
| 4 | betway |
| 5 | bwin |
| 6 | ladbrokes |
| 3 | unibet |
+----+--------------------------+
```
На слейве:
-----------
```
mysql> SELECT * FROM bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
| 1 | 1xbet |
| 4 | betway |
| 5 | bwin |
| 6 | ladbrokes |
| 3 | unibet |
+----+----------------+
```

В binlog-ах на cлейве также видно последнее изменение, туда же он пишет информацию о GTID:    
```
SET @@SESSION.GTID_NEXT= '7f20aac6-1408-11ee-a93f-5254004d77d3:2'/*!*/;
#at 418
230626 10:37:17 server id 1 end_log_pos 491 CRC32 0xd18180a2 Query thread_id=26 exec_time=0
error_code=0
SET TIMESTAMP=1534196558/*!*/;
BEGIN
/*!*/;
#at 491
230626 10:37:17 server id 1 end_log_pos 618 CRC32 0x609871c1 Query thread_id=26 exec_time=0
error_code=0
use `bet`/*!*/;
SET TIMESTAMP=1534196558/*!*/;
INSERT INTO bookmaker (id,bookmaker_name) VALUES(1,'1xbet')
/*!*/;
# at 618
#230626 10:37:17 server id 1 end_log_pos 649 CRC32 0x8d303d9d Xid = 1251
COMMIT/*!*/;

```

