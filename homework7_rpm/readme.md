Цель домашнего задания
----------------------
Создать свой собственный rpm пакет и репозиторий, размещать там ранее собранный RPM пакеты.    

Описание домашнего задания
--------------------------
```
1) Создать свой RPM пакет (можно взять свое приложение, либо собрать к примеру апач с определенными опциями).
2) Создать свой репо и разместить там свой RPM.
```

### 1) Создать свой RPM пакет.

Установливаем недостающие пакеты    
``    yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils gcc``

Собираем nginx 1.23.3 c поддержкой tls v1.3. (openssl-1.1.1q)    

 Описание используемых параметров:    
    ``--with-openssl=путь ``- задаёт путь к исходным текстам библиотеки OpenSSL.     
    ``--with-openssl-opt= ``параметры - задаёт дополнительные параметры сборки OpenSSL.    

Для примера возьмем пакет NGINX и соберём его с поддержкой openssl    
Загрузим SRPM пакет NGINX для дальнейшей работы над ним:    
    ``wget http://nginx.org/packages/mainline/centos/7/SRPMS/nginx-1.23.3-1.el7.ngx.src.rpm``
При установке такого пакета в домашней директории создается древо каталогов для сборки:    
    ``rpm -ivh nginx-1.23.3-1.el7.ngx.src.rpm``
Также нужно скачать и разархивировать последний исходник для openssl - он потребуется при сборке    
```
    wget --no-check-certificate https://www.openssl.org/source/old/1.1.1/openssl-1.1.1q.tar.gz
    tar -xvf openssl-1.1.1q.tar.gz --directory /usr/lib
```
Заранее поставим все зависимости чтобы в процессе сборки не было ошибок    
    ``yum-builddep rpmbuild/SPECS/nginx.spec``
Ну и собственно поправить сам spec файл чтобы NGINX собирался с необходимыми нам опциями:    
```    
    sed -i "s|--with-stream_ssl_preread_module|--with-stream_ssl_preread_module --with-openssl=/usr/lib/openssl-1.1.1q --with-openssl-opt=enable-tls1_3|g" /root/rpmbuild/SPECS/nginx.spec
```
Теперь можно приступить к сборке RPM пакета:
    rpmbuild -ba rpmbuild/SPECS/nginx.spec
        + umask 022
        + cd /root/rpmbuild/BUILD
        + cd nginx-1.23.3
        + /usr/bin/rm -rf /root/rpmbuild/BUILDROOT/nginx-1.23.3-1.el7.ngx.x86_64
        + exit 0

Убедимся что пакеты создались:
    ll rpmbuild/RPMS/x86_64/
-rw-r--r--. 1 root root 3774192 янв 27 13:32 nginx-1.23.3-1.el7.ngx.x86_64.rpm
-rw-r--r--. 1 root root 2042096 янв 27 13:32 nginx-debuginfo-1.23.3-1.el7.ngx.x86_64.rpm

Теперь можно установить наш пакет и убедиться что nginx работает

    yum localinstall -y /root/rpmbuild/RPMS/x86_64/nginx-1.23.3-1.el7.ngx.x86_64.rpm
    systemctl start nginx
    systemctl status nginx
           nginx.service - nginx - high performance web server
            Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
            Active: active (running) since Пт 2023-01-27 13:35:17 UTC; 4s ago
                Docs: http://nginx.org/en/docs/
            Process: 28249 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf (code=exited, status=0/SUCCESS)

Далее мы будем использовать его для доступа к своему репозиторию    

### 2) Создать свой репо и разместить там свой RPM.

Теперь приступим к созданию своего репозитория. Директория для статики у NGINX по умолчанию ``/usr/share/nginx/html``.  Создадим там каталог repo:    
    mkdir /usr/share/nginx/html/repo
    cp /root/rpmbuild/RPMS/x86_64/nginx-1.23.3-1.el7.ngx.x86_64.rpm /usr/share/nginx/html/repo/
Инициализируем репозиторий командой:
    сreaterepo /usr/share/nginx/html/repo/

            Spawning worker 0 with 1 pkgs
            Workers Finished
            Saving Primary metadata
            Saving file lists metadata
            Saving other metadata
            Generating sqlite DBs
            Sqlite DBs complete

Для прозрачности настроим в NGINX доступ к листингу каталога:
В location / в файле /etc/nginx/conf.d/default.conf добавим директиву autoindex on. 
    sed -i '/index  index.html index.htm;/a autoindex on;' /etc/nginx/conf.d/default.conf
В результате location будет выглядеть так: 

    location / {
    root /usr/share/nginx/html;
    index index.html index.htm;
    autoindex on; 
    }

Проверяем синтаксис и перезапускаем NGINX:
    nginx -t
        nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
        nginx: configuration file /etc/nginx/nginx.conf test is successful
    nginx -s reload
Все готово для того, чтобы протестировать репозиторий.
Добавим его в /etc/yum.repos.d:

     cat >> /etc/yum.repos.d/otus.repo << EOF
    [otus]
    name=otus-linux
    baseurl=http://192.168.50.10/repo
    gpgcheck=0
    enabled=1
    EOF

Теперь ради интереса можно посмотреть в браузере или curl-ануть:
    lynx http://192.168.50.10/repo/

    Index of /repo/
     _____________________________________________________________________________

../
repodata/                                          27-Jan-2023 13:44                   -
nginx-1.23.3-1.el7.ngx.x86_64.rpm                  27-Jan-2023 13:37             3774192


Убедимся что репозиторий подключился и посмотрим что в нем есть:    

    yum repolist enabled | grep otus
        otus                                otus-linux                                 1
    yum list --showduplicates | grep otus
        nginx.x86_64                             1:1.23.3-1.el7.ngx            otusS