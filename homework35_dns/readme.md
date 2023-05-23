Цель домашнего задания
----------------------
Создать домашнюю сетевую лабораторию. Изучить основы DNS, научиться работать с технологией Split-DNS в Linux-based системах.

Описание домашнего задания
--------------------------
```
1. взять стенд https://github.com/erlong15/vagrant-bind 
добавить еще один сервер client2
завести в зоне dns.lab имена:
web1 - смотрит на клиент1
web2  смотрит на клиент2
завести еще одну зону newdns.lab
завести в ней запись
www - смотрит на обоих клиентов

2. настроить split-dns
клиент1 - видит обе зоны, но в зоне dns.lab только web1
клиент2 видит только dns.lab
Формат сдачи ДЗ - vagrant + ansible
```

### 1. Работа со стендом и настройка DNS

Скачаем себе стенд ``https://github.com/erlong15/vagrant-bind``, перейдём в скаченный каталог и изучим содержимое файлов:    
```
➜  git clone https://github.com/erlong15/vagrant-bind.git
➜  cd vagrant-bind 
➜  vagrant-bind  ls -l 
total 12
drwxrwxr-x 2 alex alex 4096 мар 22 18:03 provisioning
-rw-rw-r-- 1 alex alex  414 мар 22 18:03 README.md
-rw-rw-r-- 1 alex alex  820 мар 22 18:03 Vagrantfile
```

Мы увидем файл Vagrantfile. Откроем его в любом, удобном для вас текстовом редакторе и добавим необходимую ВМ:    
```
Vagrant.configure(2) do |config|
  config.vm.box = "centos/7"

  config.vm.provision "ansible" do |ansible|
    ansible.verbose = "vvv"
    ansible.playbook = "provisioning/playbook.yml"
    ansible.become = "true"
  end
  config.vm.provider "virtualbox" do |v|
	  v.memory = 256
  end
  config.vm.define "ns01" do |ns01|
    ns01.vm.network "private_network", ip: "192.168.50.10", virtualbox__intnet: "dns"
    ns01.vm.hostname = "ns01"
  end
  config.vm.define "ns02" do |ns02|
    ns02.vm.network "private_network", ip: "192.168.50.11", virtualbox__intnet: "dns"
    ns02.vm.hostname = "ns02"
  end
  config.vm.define "client" do |client|
    client.vm.network "private_network", ip: "192.168.50.15", virtualbox__intnet: "dns"
    client.vm.hostname = "client"
  end
  config.vm.define "client2" do |client2|
    client2.vm.network "private_network", ip: "192.168.50.16", virtualbox__intnet: "dns"
    client2.vm.hostname = "client2"
  end
end
```
Запускае ``Vagrant file - vagrant up``     ``vagrant ssh``    

Перед выполнением следующих заданий, нужно обратить внимание, на каком адресе и порту работают наши DNS-сервера.    
Проверить это можно двумя способами:    
Посмотреть с помощью команды SS: ``ss -tulpn``    
[root@ns01 ~]# ``ss -ulpn``    
```
udp    UNCONN     0      0      192.168.50.10:53                    *:*                   users:(("named",pid=3582,fd=512))
udp    UNCONN     0      0         [::1]:53                 [::]:*                   users:(("named",pid=3582,fd=513))
tcp    LISTEN     0      10     192.168.50.10:53                    *:*                   users:(("named",pid=3582,fd=21))
tcp    LISTEN     0      128    192.168.50.10:953                   *:*                   users:(("named",pid=3582,fd=23))
tcp    LISTEN     0      10        [::1]:53                 [::]:*                   users:(("named",pid=3582,fd=22))
```

Посмотреть информацию в настройках DNS-сервера ``(/etc/named.conf)``    
На хосте ``ns01``:    
```  // network 
     listen-on port 53 { 192.168.50.10; };
     listen-on-v6 port 53 { ::1; };
На хосте ns02
// network 
        	listen-on port 53 { 192.168.50.11; };
	listen-on-v6 port 53 { ::1; };
```
Исходя из данной информации, нам нужно подкорректировать файл ``/etc/resolv.conf`` для DNS-серверов: на хосте ``ns01`` указать nameserver ``192.168.50.10``, а на хосте ``ns02 — 192.168.50.11``  

Добавление имён в зону dns.lab
------------------------------
Давайте проверим, что зона ``dns.lab`` уже существует на DNS-серверах:    
Фрагмент файла ``/etc/named.conf`` на сервере ``ns01``:
```
// Имя зоны
zone "dns.lab" {
    type master;
    // Тем, у кого есть ключ zonetransfer.key можно получать копию файла зоны 
    allow-transfer { key "zonetransfer.key"; };
    // Файл с настройками зоны
    file "/etc/named/named.dns.lab";
};
```
Похожий фрагмент файла ``/etc/named.conf``  находится на slave-сервере ``ns02``:
```
// Имя зоны
zone "dns.lab" {
    type slave;
    // Адрес мастера, куда будет обращаться slave-сервер
    masters { 192.168.50.10; };
};
```
Также на хосте ns01 мы видим файл ``/etc/named/named.dns.lab`` с настройкой зоны:
```
$TTL 3600
; описание зоны dns.lab.
$ORIGIN dns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201407 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11
```
Именно в этот файл нам потребуется добавить имена. Допишем в конец файла следующие строки: 
```
;Web
web1            IN      A       192.168.50.15
web2            IN      A       192.168.50.16
```
Если изменения внесены вручную, то для применения настроек нужно:    
Перезапустить службу ``named: systemctl restart named`` 
Изменить значение ``Serial`` (добавить +1 к числу 2711201407), изменение значения serial укажет slave-серверам на то, что были внесены изменения и что им надо обновить свои файлы с зонами.    
После внесения изменений, выполним проверку с клиента:    
```
[vagrant@client ~]$ dig @192.168.50.10 web1.dns.lab
; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.9 <<>> @192.168.50.10 web1.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 49207
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 2, ADDITIONAL: 3

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;web1.dns.lab.			IN	A

;; ANSWER SECTION:
web1.dns.lab.		3600	IN	A	192.168.50.15

;; AUTHORITY SECTION:
dns.lab.		3600	IN	NS	ns01.dns.lab.
dns.lab.		3600	IN	NS	ns02.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.		3600	IN	A	192.168.50.10
ns02.dns.lab.		3600	IN	A	192.168.50.11

;; Query time: 0 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Sun Mar 27 00:37:28 UTC 2022
;; MSG SIZE  rcvd: 127
```
```
[vagrant@client ~]$ dig @192.168.50.11 web2.dns.lab
; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.9 <<>> @192.168.50.11 web2.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 36834
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 2, ADDITIONAL: 3

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;web2.dns.lab.			IN	A

;; ANSWER SECTION:
web2.dns.lab.		3600	IN	A	192.168.50.16

;; AUTHORITY SECTION:
dns.lab.		3600	IN	NS	ns01.dns.lab.
dns.lab.		3600	IN	NS	ns02.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.		3600	IN	A	192.168.50.10
ns02.dns.lab.		3600	IN	A	192.168.50.11

;; Query time: 2 msec
;; SERVER: 192.168.50.11#53(192.168.50.11)
;; WHEN: Sun Mar 27 00:37:28 UTC 2022
;; MSG SIZE  rcvd: 127
```

Создание новой зоны и добавление в неё записей
----------------------------------------------

Для того, чтобы прописать на DNS-серверах новую зону нам потребуется:     
На хосте ns01 добавить зону в файл ``/etc/named.conf:``
```
// lab's newdns zone
zone "newdns.lab" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    allow-update { key "zonetransfer.key"; };
    file "/etc/named/named.newdns.lab";
};
```

На хосте ``ns02`` также добавить зону и указать с какого сервера запрашивать информацию об этой зоне (фрагмент файла ``/etc/named.conf``):
```
// lab's newdns zone
zone "newdns.lab" {
    type slave;
    masters { 192.168.50.10; };
    file "/etc/named/named.newdns.lab";
};
```

На хосте ``ns01`` создадим файл ``/etc/named/named.newdns.lab``
```
vi /etc/named/named.newdns.lab
$TTL 3600
$ORIGIN newdns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201007 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11

;WWW
www             IN      A       192.168.50.15
www             IN      A       192.168.50.16

```

В конце этого файла добавим записи ``www``.    
У файла должны быть права ``660``, владелец — ``root``, группа — ``named``.    
После внесения данных изменений, изменяем значение serial (добавлем +1 к значению 2711201007) и перезапускаем named: ``systemctl restart named``    

### 2. Настройка Split-DNS 

У нас уже есть прописанные зоны ``dns.lab и newdns.lab.`` Однако по заданию client1  должен видеть запись ``web1.dns.lab`` и не видеть запись ``web2.dns.lab.`` Client2 может видеть обе записи из домена ``dns.lab``, но не должен видеть записи домена newdns.lab Осуществить данные настройки нам поможет технология Split-DNS.    

Для настройки ``Split-DNS`` нужно:    

#### 1) Создать дополнительный файл зоны dns.lab, в котором будет прописана только одна запись:        vim /etc/named/named.dns.lab.client
```
$TTL 3600
$ORIGIN dns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201407 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11

;Web
web1            IN      A       192.168.50.15
```

Имя файла может отличаться от указанной зоны. У файла должны быть права 660, владелец — root, группа — named.      

#### 2) Внести изменения в файл /etc/named.conf на хостах ns01 и ns02

Прежде всего нужно сделать access листы для хостов client и client2. Сначала сгенерируем ключи для хостов client и client2, для этого на хосте ns01 запустим утилиту ``tsig-keygen`` (ключ может генериться 5 минут и более):    
```
[root@ns01 ~]# tsig-keygen
key "tsig-key" {
	algorithm hmac-sha256;
	secret "IxAIDfcewAtWxE5NnD54HBwXvX4EFThcW1o0DqL15oI=";
};
[root@ns01 ~]# 
```
После генерации, мы увидим ключ (secret) и алгоритм с помощью которого он был сгенерирован. Оба этих параметра нам потребуются в access листе.    
Если нам потребуется, использовать другой алгоритм, то мы можем его указать как аргумент к команде, например:  ``tsig-keygen -a hmac-md5``    
Всего нам потребуется 2 таких ключа. После их генерации добавим блок с access листами в конец файла         ``/etc/named.conf``    

```
#Описание ключа для хоста client
key "client-key" {
    algorithm hmac-sha256;
    secret "IQg171Ht4mdGYcjjYKhI9gSc1fhoxzHZB+h2NMtyZWY=";
};

#Описание ключа для хоста client2
key "client2-key" {
    algorithm hmac-sha256;
    secret "m7r7SpZ9KBcA4kOl1JHQQnUiIlpQA1IJ9xkBHwdRAHc=";
};

#Описание access-листов
acl client { !key client2-key; key client-key; 192.168.50.15; };
acl client2 { !key client-key; key client2-key; 192.168.50.16; };
```

В данном блоке access листов мы выделяем 2 блока:    
```
client имеет адрес 192.168.50.15, использует client-key и не использует client2-key
client2 имеет адрес 192ю168.50.16, использует clinet2-key и не использует client-key
```
Описание ключей и access листов будет одинаковое для master и slave сервера.    
Далее нужно создать файл с настройками зоны dns.lab для client, для этого на мастер сервере создаём файл /etc/named/named.dns.lab.client и добавляем в него следующее содержимое:    
```
$TTL 3600
$ORIGIN dns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201407 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11

;Web
web1            IN      A       192.168.50.15
```

Это почти скопированный файл зоны ``dns.lab``, в конце которого удалена строка с записью web2. Имя зоны надо оставить такой же — ``dns.lab``    
Теперь можно внести правки в ``/etc/named.conf``
Технология Split-DNS реализуется с помощью описания представлений (view), для каждого отдельного acl. В каждое представление (view) добавляются только те зоны, которые разрешено видеть хостам, адреса которых указаны в access листе.    
Все ранее описанные зоны должны быть перенесены в модули view. Вне view зон быть недолжно, зона any должна всегда находиться в самом низу.    
После применения всех вышеуказанных правил на хосте ns01 мы получим следующее содержимое файла              ``/etc/named.conf``    
```
options {

    // На каком порту и IP-адресе будет работать служба 
	listen-on port 53 { 192.168.50.10; };
	listen-on-v6 port 53 { ::1; };

    // Указание каталогов с конфигурационными файлами
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";

    // Указание настроек DNS-сервера
    // Разрешаем серверу быть рекурсивным
	recursion yes;
    // Указываем сети, которым разрешено отправлять запросы серверу
	allow-query     { any; };
    // Каким сетям можно передавать настройки о зоне
    allow-transfer { any; };
    
    // dnssec
	dnssec-enable yes;
	dnssec-validation yes;

    // others
	bindkeys-file "/etc/named.iscdlv.key";
	managed-keys-directory "/var/named/dynamic";
	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

// RNDC Control for client
key "rndc-key" {
    algorithm hmac-md5;
    secret "GrtiE9kz16GK+OKKU/qJvQ==";
};
controls {
        inet 192.168.50.10 allow { 192.168.50.15; 192.168.50.16; } keys { "rndc-key"; }; 
};

key "client-key" {
    algorithm hmac-sha256;
    secret "IQg171Ht4mdGYcjjYKhI9gSc1fhoxzHZB+h2NMtyZWY=";
};
key "client2-key" {
    algorithm hmac-sha256;
    secret "m7r7SpZ9KBcA4kOl1JHQQnUiIlpQA1IJ9xkBHwdRAHc=";
};

// ZONE TRANSFER WITH TSIG
include "/etc/named.zonetransfer.key"; 

server 192.168.50.11 {
    keys { "zonetransfer.key"; };
};
// Указание Access листов 
acl client { !key client2-key; key client-key; 192.168.50.15; };
acl client2 { !key client-key; key client2-key; 192.168.50.16; };
// Настройка первого view 
view "client" {
    // Кому из клиентов разрешено подключаться, нужно указать имя access-листа
    match-clients { client; };

    // Описание зоны dns.lab для client
    zone "dns.lab" {
        // Тип сервера — мастер
        type master;
        // Добавляем ссылку на файл зоны, который создали в прошлом пункте
        file "/etc/named/named.dns.lab.client";
        // Адрес хостов, которым будет отправлена информация об изменении зоны
        also-notify { 192.168.50.11 key client-key; };
    };

    // newdns.lab zone
    zone "newdns.lab" {
        type master;
        file "/etc/named/named.newdns.lab";
        also-notify { 192.168.50.11 key client-key; };
    };
};

// Описание view для client2
view "client2" {
    match-clients { client2; };

    // dns.lab zone
    zone "dns.lab" {
        type master;
        file "/etc/named/named.dns.lab";
        also-notify { 192.168.50.11 key client2-key; };
    };

    // dns.lab zone reverse
    zone "50.168.192.in-addr.arpa" {
        type master;
        file "/etc/named/named.dns.lab.rev";
        also-notify { 192.168.50.11 key client2-key; };
    };
};

// Зона any, указана в файле самой последней
view "default" {
    match-clients { any; };

    // root zone
    zone "." IN {
        type hint;
        file "named.ca";
    };

    // zones like localhost
    include "/etc/named.rfc1912.zones";
    // root DNSKEY
    include "/etc/named.root.key";

    // dns.lab zone
    zone "dns.lab" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        file "/etc/named/named.dns.lab";
    };

    // dns.lab zone reverse
    zone "50.168.192.in-addr.arpa" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        file "/etc/named/named.dns.lab.rev";
    };

    // ddns.lab zone
    zone "ddns.lab" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        allow-update { key "zonetransfer.key"; };
        file "/etc/named/named.ddns.lab";
    };

    // newdns.lab zone
    zone "newdns.lab" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        file "/etc/named/named.newdns.lab";
    };
};
```

Далее внесем изменения в файл ``/etc/named.conf на сервере ns02``. Файл будет похож на файл, лежащий на ``ns01``, только в настройках будет указание забирать информацию с сервера ``ns01``:
```
options {
    // network 
	listen-on port 53 { 192.168.50.11; };
	listen-on-v6 port 53 { ::1; };

    // data
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";

    // server
	recursion yes;
	allow-query     { any; };
    allow-transfer { any; };
    
    // dnssec
	dnssec-enable yes;
	dnssec-validation yes;

    // others
	bindkeys-file "/etc/named.iscdlv.key";
	managed-keys-directory "/var/named/dynamic";
	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

// RNDC Control for client
key "rndc-key" {
    algorithm hmac-md5;
    secret "GrtiE9kz16GK+OKKU/qJvQ==";
};
controls {
        inet 192.168.50.11 allow { 192.168.50.15; 192.168.50.16; } keys { "rndc-key"; };
};

key "client-key" {
    algorithm hmac-sha256;
    secret "IQg171Ht4mdGYcjjYKhI9gSc1fhoxzHZB+h2NMtyZWY=";
};
key "client2-key" {
    algorithm hmac-sha256;
    secret "m7r7SpZ9KBcA4kOl1JHQQnUiIlpQA1IJ9xkBHwdRAHc=";
};


// ZONE TRANSFER WITH TSIG
include "/etc/named.zonetransfer.key"; 

server 192.168.50.10 {
    keys { "zonetransfer.key"; };
};

acl client { !key client2-key; key client-key; 192.168.50.15; };
acl client2 { !key client-key; key client2-key; 192.168.50.16; };

view "client" {
    match-clients { client; };
    allow-query { any; };

    // dns.lab zone
    zone "dns.lab" {
        // Тип сервера — slave
        type slave;
        // Будет забирать информацию с сервера 192.168.50.10
        masters { 192.168.50.10 key client-key; };
    };

    // newdns.lab zone
    zone "newdns.lab" {
        type slave;
        masters { 192.168.50.10 key client-key; };
    };
};

view "client2" {
    match-clients { client2; };

    // dns.lab zone
    zone "dns.lab" {
        type slave;
        masters { 192.168.50.10 key client2-key; };
    };

    // dns.lab zone reverse
    zone "50.168.192.in-addr.arpa" {
        type slave;
        masters { 192.168.50.10 key client2-key; };
    };
};

view "default" {
    match-clients { any; };

    // root zone
    zone "." IN {
        type hint;
        file "named.ca";
    };

    // zones like localhost
    include "/etc/named.rfc1912.zones";
    // root DNSKEY
    include "/etc/named.root.key";

    // dns.lab zone
    zone "dns.lab" {
        type slave;
        masters { 192.168.50.10; };
    };

    // dns.lab zone reverse
    zone "50.168.192.in-addr.arpa" {
        type slave;
        masters { 192.168.50.10; };
    };

    // ddns.lab zone
    zone "ddns.lab" {
        type slave;
        masters { 192.168.50.10; };
    };

    // newdns.lab zone
    zone "newdns.lab" {
        type slave;
        masters { 192.168.50.10; };
    };
};
```

Так как файлы с конфигурациями получаются достаточно большими — возрастает вероятность сделать ошибку. При их правке можно воспользоваться утилитой ``named-checkconf``. Она укажет в каких строчках есть ошибки. Использование данной утилиты рекомендуется после изменения настроек на DNS-сервере.    
После внесения данных изменений можно перезапустить (по очереди) службу named на серверах ``ns01 и ns02``.   
Далее, нужно будет проверить работу Split-DNS с хостов client и client2. Для проверки можно использовать утилиту ``ping``:    

Проверка на client:
-------------------
```
[root@client ~]# ping www.newdns.lab
PING www.newdns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client (192.168.50.15): icmp_seq=1 ttl=64 time=0.014 ms
64 bytes from client (192.168.50.15): icmp_seq=2 ttl=64 time=0.066 ms
^C
--- www.newdns.lab ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 0.014/0.040/0.066/0.026 ms
[root@client ~]# ping web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client (192.168.50.15): icmp_seq=1 ttl=64 time=0.015 ms
64 bytes from client (192.168.50.15): icmp_seq=2 ttl=64 time=0.068 ms
^C
--- web1.dns.lab ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1005ms
rtt min/avg/max/mdev = 0.015/0.041/0.068/0.027 ms
[root@client ~]# ping web2.dns.lab
ping: web2.dns.lab: Name or service not known
[root@client ~]# ^C
[root@client ~]# 
```
На хосте мы видим, что ``client`` видит обе зоны ``(dns.lab и newdns.lab)``, однако информацию о хосте ``web2.dns.lab` он получить не может.    

Проверка на client2:
-------------------
```
[root@client2 ~]# ping www.newdns.lab
ping: www.newdns.lab: Name or service not known
[root@client2 ~]# 
[root@client2 ~]# ping web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=1 ttl=64 time=0.809 ms
^C
--- web1.dns.lab ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.809/0.809/0.809/0.000 ms
[root@client2 ~]# ping web2.dns.lab
PING web2.dns.lab (192.168.50.16) 56(84) bytes of data.
64 bytes from client2 (192.168.50.16): icmp_seq=1 ttl=64 time=0.037 ms
64 bytes from client2 (192.168.50.16): icmp_seq=2 ttl=64 time=0.065 ms
^C
--- web2.dns.lab ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1038ms
rtt min/avg/max/mdev = 0.037/0.051/0.065/0.014 ms
[root@client2 ~]# 
```

Тут мы понимаем, что client2 видит всю зону ``dns.lab`` и не видит зону ``newdns.lab``
