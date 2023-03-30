Цель домашнего задания
----------------------
Научится проектировать централизованный сбор логов. Рассмотреть особенности разных платформ для сбора     логов.    

Описание домашнего задания
--------------------------
```
1. В Vagrant разворачиваем 2 виртуальные машины web и log    
2. на web настраиваем nginx    
3. на log настраиваем центральный лог сервер на любой системе на выбор    
journald;    
rsyslog;    
elk.    
4. настраиваем аудит, следящий за изменением конфигов nginx    
```

Все критичные логи с web должны собираться и локально и удаленно.    
Все логи с nginx должны уходить на удаленный сервер (локально только критичные).    
Логи аудита должны также уходить на удаленную систему.    

В ОС Linux главным файлом локального журналирования является:    
Ubuntu/Debian — /var/log/syslog    
RHEL/CentOS — /var/log/messages    

### 1. В Vagrant разворачиваем 2 виртуальные машины web и log  

Создаём каталог, в котором будут храниться настройки виртуальной машины. В каталоге создаём файл с именем Vagrantfile, добавляем в него следующее содержимое:    
```
# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure(2) do |config|
    config.vm.box = "centos/7"
    config.vm.box_version = "2004.01"
  
    config.vm.provider "virtualbox" do |v|
      v.memory = 1024
      v.cpus = 1
    end
  
    config.vm.define "web" do |web|
      web.vm.network "private_network", ip: "192.168.50.10"
      web.vm.hostname = "web"
    end
  
    config.vm.define "log" do |log|
      log.vm.network "private_network", ip: "192.168.50.15"
      log.vm.hostname = "log"
    end
  
  end
```
vagrant up делает 2 созданные виртуальные машины    
Заходим на web-сервер: ``vagrant ssh web``    
Дальнейшие действия выполняются от пользователя ``root``. Переходим в root пользователя: ``sudo -i``    
Для правильной работы c логами, нужно, чтобы на всех хостах было настроено одинаковое время.    
Укажем часовой пояс (Московское время):    
``cp /usr/share/zoneinfo/Europe/Moscow /etc/localtime``    
Перезупустим службу ``NTP Chrony: systemctl restart chronyd``    
Проверим, что служба работает корректно: ``systemctl status chronyd``    

### 2. Установка nginx на виртуальной машине web

Для установки ``nginx`` сначала нужно установить ``epel-release``: ``yum install epel-release``    
Установим ``nginx``: ``yum install -y nginx``    
Проверим, что ``nginx`` работает корректно:    
```
systemctl status nginx.service 
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: active (running) since Wed 2023-03-29 08:57:07 MSK; 1s ago
  Process: 3550 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 3548 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
  Process: 3547 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 3552 (nginx)
   CGroup: /system.slice/nginx.service
           ├─3552 nginx: master process /usr/sbin/nginx
           └─3553 nginx: worker process
```

Проверяем открытие порта ``ss -tln | grep 80``   
```
State      Recv-Q Send-Q Local Address:Port               Peer Address:Port                          
LISTEN     0      128          *:80                       *:*                                  
LISTEN     0      128       [::]:80                    [::]:*                  
```
Также работу ``nginx`` можно проверить на хосте.    
В браузере ввведем в адерсную строку ``http://192.168.50.10``    
![Иллюстрация к проекту](https://github.com/aleksandr1895/Otus-Administrator-Linux-Professional/blob/master/homework23_Rsyslog/nginx.png)
Видим что nginx запустился корректно.    

### 3. Настройка центрального сервера сбора логов

Откроем ещё одно окно терминала и подключимся по ``ssh`` к ВМ ``log``: ``vagrant ssh log``    
Перейдем в пользователя root: ``sudo -i``    
``rsyslog`` должен быть установлен по умолчанию в нашёй ОС, проверим это:    

``yum list rsyslog``    
```
Installed Packages
rsyslog.x86_64
8.24.0-52.el7
@anaconda
Available Packages
rsyslog.x86_64
8.24.0-57.el7_9.3
updates 
```
Все настройки ``Rsyslog`` хранятся в файле ``/etc/rsyslog.conf``    
Для того, чтобы наш сервер мог принимать логи, нам необходимо внести следующие изменения в файл:    
Открываем порт ``514`` (TCP и UDP):     
Находим закомментированные строки:    
И приводим их к виду:    
```
# Provides UDP syslog reception
$ModLoad imudp
$UDPServerRun 514

# Provides TCP syslog reception
$ModLoad imtcp
$InputTCPServerRun 514
```
В конец файла ``/etc/rsyslog.conf`` добавляем правила приёма сообщений от хостов:    
```
#Add remote logs
$template RemoteLogs, "/var/log/rsyslog/%HOSTNAME%/%PROGRAMNAME%.log"
*.* ?RemoteLogs
& ~
```
Данные параметры будут отправлять в папку ``/var/log/rsyslog`` логи, которые будут приходить от других серверов. Например, ``Access-логи nginx`` от сервера ``web``, будут идти в файл ``/var/log/rsyslog/web/nginx_access.log``    
Далее сохраняем файл и перезапускаем службу ``rsyslog: systemctl restart rsyslog``    
Если ошибок не допущено, то у нас будут видны открытые порты ``TCP,UDP 514``:    
```
ss -tuln | grep 514
udp    UNCONN     0      0         *:514                   *:*                  
udp    UNCONN     0      0      [::]:514                [::]:*                  
tcp    LISTEN     0      25        *:514                   *:*                  
tcp    LISTEN     0      25     [::]:514                [::]:*  
```
Далее настроим отправку логов с ``web-сервера``    

Проверим версию nginx: ``rpm -qa | grep nginx``    
```
nginx-filesystem-1.20.1-10.el7.noarch
nginx-1.20.1-10.el7.x86_64
```
Находим в файле ``/etc/nginx/nginx.conf`` раздел с логами и приводим их к следующему виду:    
```
error_log /var/log/nginx/error.log;
error_log syslog:server=192.168.50.15:514,tag=nginx_error notice;
access_log syslog:server=192.168.50.15:514,tag=nginx_access,severity=info combined;
```
Для ``Access-логов`` указыаем удаленный сервер и уровень логов, которые нужно отправлять.     
Для ``error_log`` добавляем удаленный сервер. Если требуется чтобы логи хранились локально и отправлялись на удаленный сервер, требуется указать 2 строки. 	  
Tag нужен для того, чтобы логи записывались в разные файлы.    
По умолчанию, ``error-логи`` отправляют логи, которые имеют ``severity: error, crit, alert и emerg``.    Если трубуется хранили или пересылать логи с другим ``severity``, то это также можно указать в настройках nginx. Далее проверяем, что конфигурация nginx указана правильно:    
```  
nginx -t    
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```
Далее перезапустим nginx: ``systemctl restart nginx``    
Чтобы проверить, что логи ошибок также улетают на удаленный сервер, можно удалить картинку, к которой будет обращаться nginx во время открытия web-страницы    
``rm /usr/share/nginx/html/img/header-background.png``    
Попробуем несколько раз зайти по адресу ``http://192.168.50.10`` 
Далее заходим на log-сервер и смотрим информацию об ``nginx``:    
```
cat /var/log/rsyslog/web/nginx_access.log    

Mar 29 11:11:01 web nginx_access: 192.168.50.1 - - [29/Mar/2023:11:11:01 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36"
Mar 29 11:11:03 web nginx_access: 192.168.50.1 - - [29/Mar/2023:11:11:03 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36"
Mar 29 11:12:29 web nginx_access: 192.168.50.1 - - [29/Mar/2023:11:12:29 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36"
Mar 29 11:12:30 web nginx_access: 192.168.50.1 - - [29/Mar/2023:11:12:30 +0300] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36"
```
![Иллюстрация к проекту](https://github.com/aleksandr1895/Otus-Administrator-Linux-Professional/blob/master/homework23_Rsyslog/Rsysloga.png)
```
cat /var/log/rsyslog/web/nginx_error.log 

ar 29 11:29:26 web nginx_error: 2023/03/29 11:29:26 [error] 22376#22376: *3 open() "/usr/share/nginx/html/graph" failed (2: No such file or directory), client: 192.168.50.1, server: _, request: "GET /graph HTTP/1.1", host: "192.168.50.10"
Mar 29 11:29:31 web nginx_error: 2023/03/29 11:29:31 [error] 22376#22376: *3 open() "/usr/share/nginx/html/graph" failed (2: No such file or directory), client: 192.168.50.1, server: _, request: "GET /graph HTTP/1.1", host: "192.168.50.10"
Mar 29 11:29:32 web nginx_error: 2023/03/29 11:29:32 [error] 22376#22376: *3 open() "/usr/share/nginx/html/graph" failed (2: No such file or directory), client: 192.168.50.1, server: _, request: "GET /graph HTTP/1.1", host: "192.168.50.10"
```
![Иллюстрация к проекту](https://github.com/aleksandr1895/Otus-Administrator-Linux-Professional/blob/master/homework23_Rsyslog/Rsysloge.png)
### 4. Настройка аудита, контролирующего изменения конфигурации nginx

За аудит отвечает утилита auditd, в ``RHEL-based`` системах обычно он уже предустановлен.    
```
rpm -qa | grep audit

audit-2.8.5-4.el7.x86_64
audit-libs-2.8.5-4.el7.x86_64
```

Настроим аудит изменения конфигурации nginx:    
Добавим правило, которое будет отслеживать изменения в конфигруации ``nginx``.    
Для этого в конец файла ``/etc/audit/rules.d/audit.rules`` добавим следующие строки:    
```
-w /etc/nginx/nginx.conf -p wa -k nginx_conf
-w /etc/nginx/default.d/ -p wa -k nginx_conf
```
Данные правила позволяют контролировать запись (w) и измения атрибутов (a) в: ``/etc/nginx/nginx.conf``    
Всех файлов каталога ``/etc/nginx/default.d/``    
Для более удобного поиска к событиям добавляется метка ``nginx_conf``    
Перезапускаем службу ``auditd``: ``service auditd restart``    

После данных изменений у нас начнут локально записываться логи аудита. Чтобы проверить, что логи аудита начали записываться локально, нужно внести изменения в файл ``/etc/nginx/nginx.conf`` или поменять его атрибут, потом посмотреть информацию об изменениях:
```
ausearch -f /etc/nginx/nginx.conf

time->Wed Mar 29 13:00:51 2023
node=web type=PROCTITLE msg=audit(1680084051.875:1094): proctitle=63686D6F6400752B782C672D782C6F2D78002F6574632F6E67696E782F6E67696E782E636F6E66
node=web type=PATH msg=audit(1680084051.875:1094): item=0 name="/etc/nginx/nginx.conf" inode=67151068 dev=08:01 mode=0100755 ouid=0 ogid=0 rdev=00:00 obj=system_u:object_r:httpd_config_t:s0 objtype=NORMAL cap_fp=0000000000000000 cap_fi=0000000000000000 cap_fe=0 cap_fver=0
node=web type=CWD msg=audit(1680084051.875:1094):  cwd="/root"
node=web type=SYSCALL msg=audit(1680084051.875:1094): arch=c000003e syscall=268 success=yes exit=0 a0=ffffffffffffff9c a1=aa7440 a2=1e4 a3=7fff9c3c4ea0 items=1 ppid=3304 pid=23323 auid=1000 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=pts0 ses=4 comm="chmod" exe="/usr/bin/chmod" subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 key="nginx_conf"
```

Также можно воспользоваться поиском по файлу ``/var/log/audit/audit.log``, указав наш тэг:    
```
grep nginx_conf /var/log/audit/audit.log    
node=web type=CONFIG_CHANGE msg=audit(1680083826.676:1091): auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 op=add_rule key="nginx_conf" list=4 res=1
node=web type=CONFIG_CHANGE msg=audit(1680083826.676:1092): auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 op=add_rule key="nginx_conf" list=4 res=1
node=web type=SYSCALL msg=audit(1680084051.875:1094): arch=c000003e syscall=268 success=yes exit=0 a0=ffffffffffffff9c a1=aa7440 a2=1e4 a3=7fff9c3c4ea0 items=1 ppid=3304 pid=23323 auid=1000 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=pts0 ses=4 comm="chmod" exe="/usr/bin/chmod" subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 key="nginx_conf"
```


Далее настроим пересылку логов на удаленный сервер. ``Auditd`` по умолчанию не умеет пересылать логи, для пересылки на ``web-сервере`` потребуется установить пакет ``audispd-plugins``:    
``yum -y install audispd-plugins``    
Найдем и поменяем следующие строки в файле ``/etc/audit/auditd.conf:``    
``log_format = RAW
   name_format = HOSTNAME``    

В файле ``/etc/audisp/plugins.d/au-remote.conf`` поменяем параметр active на yes:
```
active = yes 
direction = out
path = /sbin/audisp-remote
type = always
#args =
format = string
```
В файле ``/etc/audisp/audisp-remote.conf`` требуется указать адрес сервера и порт, на который будут отправляться логи:    
```
remote_server = 192.168.50.15
port = 60
```
Далее перезапускаем службу ``auditd``: ``service auditd restart``    
На этом настройка web-сервера завершена. Далее настроим Log-сервер.    

Отроем порт ``TCP 60``, для этого уберем значки комментария в файле ``/etc/audit/auditd.conf:``    

``tcp_listen_port = 60``

Перезапустим службу ``auditd``: ``service auditd restart``    
На этом настройка пересылки логов аудита закончена. Можем попробовать поменять атрибут у файла    
``/etc/nginx/nginx.conf`` и проверить на ``log-сервере``, что пришла информация об изменении атрибута:    
```
ls -lh /etc/nginx/nginx.conf
-rw-r--r--. 1 root root 2.5K Mar 29 11:50 /etc/nginx/nginx.conf
[root@web ~]# chmod u+x /etc/nginx/nginx.conf
[root@web ~]# ls -lh /etc/nginx/nginx.conf
-rwxr--r--. 1 root root 2.5K Mar 29 11:50 /etc/nginx/nginx.conf
```

```
grep web /var/log/audit/audit.log

node=web type=DAEMON_START msg=audit(1680082797.142:1061): op=start ver=2.8.5 format=raw kernel=3.10.0-1127.el7.x86_64 auid=4294967295 pid=23103 uid=0 ses=4294967295 subj=system_u:system_r:auditd_t:s0 res=success
node=web type=CONFIG_CHANGE msg=audit(1680082797.318:1082): audit_backlog_limit=8192 old=8192 auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 res=1
node=web type=CONFIG_CHANGE msg=audit(1680082797.319:1083): audit_failure=1 old=1 auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 res=1
node=web type=SERVICE_START msg=audit(1680082797.333:1084): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=auditd comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'
node=web type=DAEMON_END msg=audit(1680083825.445:1062): op=terminate auid=1000 pid=23266 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 res=success
node=web type=DAEMON_START msg=audit(1680083826.510:2286): op=start ver=2.8.5 format=raw kernel=3.10.0-1127.el7.x86_64 auid=4294967295 pid=23283 uid=0 ses=4294967295 subj=system_u:system_r:auditd_t:s0 res=success
node=web type=CONFIG_CHANGE msg=audit(1680083826.672:1089): audit_backlog_limit=8192 old=8192 auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 res=1
node=web type=CONFIG_CHANGE msg=audit(1680083826.674:1090): audit_failure=1 old=1 auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 res=1
node=web type=CONFIG_CHANGE msg=audit(1680083826.676:1091): auid=4294967295 ses=4294967295 subj=system_u:system_r:unconfined_service_t:s0 op=add_rule key="nginx_conf" list=4 res=1
```









