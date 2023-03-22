Цель домашнего задания
----------------------
    Научиться работать с SystemD

Описание домашнего задания
--------------------------
```
1.Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig).
2.Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi).
3.Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами.
```

### 1.Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig).

Для начала создаём файл с конфигурацией для сервиса в директории ``/etc/sysconfig`` - из неё сервис будет брать необходимые переменные.    
```
vi /etc/sysconfig/watchlog
    # Configuration file for my watchlog service
    # Place it to /etc/sysconfig

    # File and word in that file that we will be monit
    WORD="ALERT"
    LOG=/var/log/watchlog.log
```
Затем создаем ``/var/log/watchlog.log`` и пишем туда строки на своё усмотрение, плюс ключевое слово ``‘ALERT’``
    
   echo `/bin/date "+%b %d %T"` ALERT >> /var/log/watchlog.log    
```
vi /opt/watchlog.sh
    #!/bin/bash

    WORD=$1
    LOG=$2
    DATE=`date`

    if grep $WORD $LOG &> /dev/null
    then
    logger "$DATE: I found word, Master!"
    else
    exit 0
    fi
```

Команда logger отправляет лог в системный журнал    
Добавим права на запуск файла:    

Создаём unit-файл сервиса:    
```
vi /etc/systemd/system/watchlog.service
    [Unit]
    Description=My watchlog service

    [Service]
    Type=oneshot
    EnvironmentFile=/etc/sysconfig/watchlog
    ExecStart=/opt/watchlog.sh $WORD $LOG
    Создаём unit-файл таймера:
```
```
vi /etc/systemd/system/watchlog.timer
    [Unit]
    Description=Run watchlog script every 30 second

    [Timer]
    # Run every 30 second
    OnUnitActiveSec=30
    Unit=watchlog.service

    [Install]
    WantedBy=multi-user.target
```
Затем достаточно только стартануть timer:    
    ``systemctl start watchlog.timer``

И убедитþся в результате:
```
tail -f /var/log/messages
    Feb  3 05:50:19 systemd systemd: Created slice User Slice of vagrant.
    Feb  3 05:50:20 systemd systemd: Started Session 1 of user vagrant.
    Feb  3 05:50:20 systemd systemd-logind: New session 1 of user vagrant.
    Feb  3 05:53:10 systemd chronyd[380]: Selected source 89.221.207.113
    Feb  3 06:01:01 systemd systemd: Created slice User Slice of root.
    Feb  3 06:01:01 systemd systemd: Started Session 2 of user root.
    Feb  3 06:01:56 systemd systemd: Starting My watchlog service...
    Feb  3 06:01:56 systemd root: Fri Feb  3 06:01:56 UTC 2023: I found word, Master!
    Feb  3 06:01:56 systemd systemd: Started My watchlog service.
    Feb  3 06:02:04 systemd systemd: Started Run watchlog script every 30 second.
    Feb  3 06:04:15 systemd systemd: Starting Cleanup of Temporary Directories...
    Feb  3 06:04:16 systemd systemd: Started Cleanup of Temporary Directories.
```

### 2.Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно так же называться)

Устанавливаем ``spawn-fcgi`` и необходимые для него пакеты:    
    ``yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y``    

``/etc/rc.d/init.d/spawn-fcgi`` - cам Init скрипт, который будем переписывать    

Но перед этим необходимо раскомментировать строки с переменными в ``/etc/sysconfig/spawn-fcgi``    

Он должен получиться следующего вида:    
```
vi /etc/sysconfig/spawn-fcgi
    # You must set some working options before the "spawn-fcgi" service will wovirk.
    # If SOCKET points to a file, then this file is cleaned up by the init script.
    #
    # See spawn-fcgi(1) for all possible options.
    #
    # Example :
    SOCKET=/var/run/php-fcgi.sock
    OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
```
А сам юнит файл будет примерно следующего вида:    
```
vi /etc/systemd/system/spawn-fcgi.service
    [Unit]
    Description=Spawn-fcgi startup service by Otus
    After=network.target

    [Service]
    Type=simple
    PIDFile=/var/run/spawn-fcgi.pid
    EnvironmentFile=/etc/sysconfig/spawn-fcgi
    ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
    KillMode=process

    [Install]
    WantedBy=multi-user.target
```
Убеждаемся что все успешно работает:    
```
systemctl start spawn-fcgi

systemctl status spawn-fcgi

    spawn-fcgi.service - Spawn-fcgi startup service by Otus
    Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
    Active: active (running) since Fri 2023-02-03 06:48:41 UTC; 10s ago
    Main PID: 20138 (php-cgi)
    CGroup: /system.slice/spawn-fcgi.service
            ├─20138 /usr/bin/php-cgi
            ├─20139 /usr/bin/php-cgi
            ├─20140 /usr/bin/php-cgi
            ├─20141 /usr/bin/php-cgi
            ├─20142 /usr/bin/php-cgi
            ├─20143 /usr/bin/php-cgi
            ├─20144 /usr/bin/php-cgi
            ├─20145 /usr/bin/php-cgi
            ├─20146 /usr/bin/php-cgi
            ├─20147 /usr/bin/php-cgi
            ├─20148 /usr/bin/php-cgi
            ├─20149 /usr/bin/php-cgi
            ├─20150 /usr/bin/php-cgi
            ├─20151 /usr/bin/php-cgi
            ├─20152 /usr/bin/php-cgi
            ├─20153 /usr/bin/php-cgi
            ├─20154 /usr/bin/php-cgi
            ├─20155 /usr/bin/php-cgi
            ├─20156 /usr/bin/php-cgi
            ├─20157 /usr/bin/php-cgi
            ├─20158 /usr/bin/php-cgi
            ├─20159 /usr/bin/php-cgi
            ├─20160 /usr/bin/php-cgi
            ├─20161 /usr/bin/php-cgi
            ├─20162 /usr/bin/php-cgi
            ├─20163 /usr/bin/php-cgi
            ├─20164 /usr/bin/php-cgi
            ├─20165 /usr/bin/php-cgi
            ├─20166 /usr/bin/php-cgi
            ├─20167 /usr/bin/php-cgi
            ├─20168 /usr/bin/php-cgi
            ├─20169 /usr/bin/php-cgi
            └─20170 /usr/bin/php-cgi

    Feb 03 06:48:41 systemd systemd[1]: Started Spawn-fcgi startup service by Otus.
    Hint: Some lines were ellipsized, use -l to show in full.
```

### 3. Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами.

Для запуска нескольких экземпляров сервиса будем использовать шаблон в конфигурации файла окружения    
``(/usr/lib/systemd/system/httpd.service )``:    
Копируем файл из ``/usr/lib/systemd/system/``, ``cp /usr/lib/systemd/system/httpd.service /etc/systemd/system`` 
далее переименовываем ``mv /etc/systemd/system/httpd.service /etc/systemd/system/httpd@.service`` и приводим к виду:
```
vi httpd@first.service 
    [Unit]
    Description=The Apache HTTP Server
    After=network.target remote-fs.target nss-lookup.target
    Documentation=man:httpd(8)
    Documentation=man:apachectl(8)

    [Service]
    Type=notify
    EnvironmentFile=/etc/sysconfig/httpd-%I
    ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
    ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
    ExecStop=/bin/kill -WINCH ${MAINPID}
    # We want systemd to give httpd some time to finish gracefully, but still want
    # it to kill httpd after TimeoutStopSec if something went wrong during the
    # graceful stop. Normally, Systemd sends SIGTERM signal right after the
    # ExecStop, which would kill httpd. We are sending useless SIGCONT here to give
    # httpd time to finish.
    KillSignal=SIGCONT
    PrivateTmp=true

    [Install]
    WantedBy=multi-user.target
```
```
vi httpd@second.service 
    [Unit]
    Description=The Apache HTTP Server
    After=network.target remote-fs.target nss-lookup.target
    Documentation=man:httpd(8)
    Documentation=man:apachectl(8)

    [Service]
    Type=notify
    EnvironmentFile=/etc/sysconfig/httpd-%I
    ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
    ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
    ExecStop=/bin/kill -WINCH ${MAINPID}
    # We want systemd to give httpd some time to finish gracefully, but still want
    # it to kill httpd after TimeoutStopSec if something went wrong during the
    # graceful stop. Normally, Systemd sends SIGTERM signal right after the
    # ExecStop, which would kill httpd. We are sending useless SIGCONT here to give
    # httpd time to finish.
    KillSignal=SIGCONT
    PrivateTmp=true

    [Install]
    WantedBy=multi-user.target
```
В самом файле окружения (которых будет два) задается опция для запуска веб-сервера с необходимм конфигурационным файлом:    

# /etc/sysconfig/httpd-first
``OPTIONS=-f conf/first.conf``    

# /etc/sysconfig/httpd-second
``OPTIONS=-f conf/second.conf``    

Соответственно в директорию с конфигами ``httpd``, кладём 2 конфига ``first.conf и second.conf``:    
```
vi /etc/httpd/conf/first.conf 
    PidFile "/var/run/httpd-first.pid"
    Listen 8080

vi /etc/httpd/conf/second.conf 
    PidFile "/var/run/httpd-second.pid"
    Listen 8088
```