Цель домашнего задания
----------------------
Описание домашнего задания
--------------------------
```
Настроить стенд Vagrant с двумя виртуальными машинами: backup_server и client. (Студент самостоятельно настраивает Vagrant)
Настроить удаленный бэкап каталога /etc c сервера client при помощи borgbackup. Резервные копии должны соответствовать следующим критериям:
директория для резервных копий /var/backup. 
имя бэкапа должно содержать информацию о времени снятия бекапа;
глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех. Последние три месяца должны содержать копии на каждый день. Т.е. должна быть правильно настроена политика удаления старых бэкапов;
резервная копия снимается каждые 5 минут. Такой частый запуск в целях демонстрации;
написан скрипт для снятия резервных копий. Скрипт запускается из соответствующей Cron джобы, либо systemd timer-а - на ваше усмотрение;
настроено логирование процесса бекапа. Для упрощения можно весь вывод перенаправлять в logger с соответствующим тегом. Если настроите не в syslog, то обязательна ротация логов.
```
### Установка сервера 

Подключаем EPEL репозиторий с дополнительными пакетами    
``yum install epel-release**``    
	
Устанавливаем на client и backup сервере borgbackup    
``yum install borgbackup``    

На сервере backup создаем пользователя и каталог /var/backup и назначаем на него права пользователя borg    
```
useradd -m borg    
mkdir /var/backup
chown borg:borg /var/backup/
```

На сервер backup создаем каталог ``~/.ssh/authorized_keys`` в каталоге ``/home/borg``    
```
	# su - borg
	# mkdir .ssh
   	# touch .ssh/authorized_keys
   	# chmod 700 .ssh
   	# chmod 600 .ssh/authorized_keys
```
### Установка клиента

Подключаем EPEL репозиторий с дополнительными пакетами    
``yum install epel-release**``    
	
Устанавливаем на client и backup сервере borgbackup    
``yum install borgbackup``    

Делаем ключ авторизации ``ssh-keygen``
После завершения команды будут созданы два файла /root/.ssh/id_rsa и /root/.ssh/id_rsa.pub — файл закрытого ключа id_rsa и файл публичного ключа id_rsa.pub.    
Просмотрим содержимое публичного ключа и скопируем его в authorized_keys на сервере.

Инициализируем репозиторий borg на backup сервере с client сервера:    
```
borg init --encryption=repokey borg@192.168.11.160:/var/backup/``

The authenticity of host '192.168.11.160 (192.168.11.160)' can't be established.
ECDSA key fingerprint is SHA256:ixCVrazuhMePamrU7xkUUsp42kRF2Mv54seGqLZGyCY.
ECDSA key fingerprint is MD5:f8:97:00:5f:55:df:0b:3f:d2:bf:b0:e4:75:fb:52:6d.
Are you sure you want to continue connecting (yes/no)? yes
Remote: Warning: Permanently added '192.168.11.160' (ECDSA) to the list of known hosts.
Enter new passphrase: 
Enter same passphrase again: 
Do you want your passphrase to be displayed for verification? [yN]:
By default repositories initialized with this version will produce security
errors if written to with an older version (up to and including Borg 1.0.8).
If you want to use these older versions, you can disable the check by running:
borg upgrade --disable-tam ssh://borg@192.168.11.160/var/backup
See https://borgbackup.readthedocs.io/en/stable/changes.html#pre-1-0-9-manifest-spoofing-vulnerability for details about the security implications.
IMPORTANT: you will need both KEY AND PASSPHRASE to access this repo!
If you used a repokey mode, the key is stored in the repo, but you should back it up separately.
Use "borg key export" to export the key, optionally in printable format.
Write down the passphrase. Store both at safe place(s).
```
Запускаем для проверки создания бэкапа    
```
borg create --stats --list borg@192.168.11.160:/var/backup/::"etc-{now:%Y-%m-%d_%H:%M:%S}" /etc
Enter passphrase for key ssh://borg@192.168.11.160/var/backup:

------------------------------------------------------------------------------
Archive name: etc-2023-06-06_06:26:04
Archive fingerprint: b8f2badff6ac5cea69e6a10086306a990fa31bcde46446534c0b6908b4d267e0
Time (start): Tue, 2023-06-06 06:26:11
Time (end):   Tue, 2023-06-06 06:26:23
Duration: 12.32 seconds
Number of files: 1697
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:               28.41 MB             13.49 MB             11.84 MB
All archives:               28.41 MB             13.49 MB             11.84 MB

                       Unique chunks         Total chunks
Chunk index:                    1277                 1692
------------------------------------------------------------------------------
```

Смотрим, что у нас получилось    
```
borg list borg@192.168.11.160:/var/backup/
Enter passphrase for key ssh://borg@192.168.11.160/var/backup: 

etc-2023-06-06_06:26:04              Tue, 2023-06-06 06:26:11 [b8f2badff6ac5cea69e6a10086306a990fa31bcde46446534c0b6908b4d267e0]
```
Смотрим список файлов    
``borg list borg@192.168.11.160:/var/backup/::etc-2023-06-06_06:26:04``

Достаем файл из бекапа    
``borg extract borg@192.168.11.160:/var/backup/::etc-2023-06-06_06:26:04``

Автоматизируем создание бэкапов с помощью ``systemd``
-----------------------------------------------------
Создаем сервис и таймер в каталоге ``/etc/systemd/system/``
```
vi /etc/systemd/system/borg-backup.service
[Unit]
Description=Borg Backup
[Service]
Type=oneshot
# Парольная фраза
Environment="BORG_PASSPHRASE=Otus1234"
# Репозиторий
Environment=REPO=borg@192.168.11.160:/var/backup/
# Что бэкапим
Environment=BACKUP_TARGET=/etc
# Создание бэкапа
ExecStart=/bin/borg create \
    --stats                \
    ${REPO}::etc-{now:%%Y-%%m-%%d_%%H:%%M:%%S} ${BACKUP_TARGET}
# Проверка бэкапа
ExecStart=/bin/borg check ${REPO}
# Очистка старых бэкапов
ExecStart=/bin/borg prune \
    --keep-daily  90      \
    --keep-monthly 12     \
    --keep-yearly  1       \
    ${REPO}
```

```
vi /etc/systemd/system/borg-backup.timer
[Unit]
Description=Borg Backup
[Timer]
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
```

И запускаем спужбу    