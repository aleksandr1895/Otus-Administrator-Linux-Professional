Цель домашнего задания
----------------------
Научиться работать с VPN

Описание домашнего задания
--------------------------
```
1. Между двумя виртуалками поднять vpn в режимах:
- tun
- tap
Описать в чём разница, замерить скорость между виртуальными машинами в туннелях, сделать вывод об отличающихся показателях скорости.
2. Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на виртуалку.
```

### 1. Между двумя виртуалками поднять vpn в режимах: - tun - tap

#### 1. Типовой Vagrantfile для данной задачи:    
```
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
config.vm.box = "centos/stream8"
config.vm.define "server" do |server|
server.vm.hostname = "server.loc"
server.vm.network "private_network", ip: "192.168.56.10"
end
config.vm.define "client" do |client|
client.vm.hostname = "client.loc"
client.vm.network "private_network", ip: "192.168.56.20"
end
end
```
#### 2. После запуска машин из Vagrantfile заходим на ВМ server и выполняем следующие действия на server и client машинах:

● устанавливаем epel репозиторий: ``yum install -y epel-release``      
● устанавливаем пакет openvpn и ``iperf3`` ``yum install -y openvpn iperf3``    
● Отключаем SELinux (при желании можно написать правило для openvpn) setenforce 0 (работает до ребута)    
#### 3. Настройка openvpn сервера:

● создаём файл-ключ ``openvpn --genkey --secret /etc/openvpn/static.key``    
● создаём конфигурационный файл vpn-сервера    

``vi /etc/openvpn/server.conf``    
```
dev tap
ifconfig 10.10.10.1 255.255.255.0
topology subnet
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```

```
vi /etc/systemd/system/openvpn@.service

[Unit]
Description=OpenVPN Tunneling Application On %I
After=network.target
[Service]
Type=notify
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf
[Install]
WantedBy=multi-user.target
```

Запускаем openvpn сервер и добавляем в автозагрузку    

``systemctl start openvpn@server``    
``systemctl enable openvpn@server``    
```
systemctl status openvpn@server
● openvpn@server.service - OpenVPN Tunneling Application On server
   Loaded: loaded (/etc/systemd/system/openvpn@.service; enabled; vendor preset>
   Active: active (running) since Fri 2023-05-19 12:27:02 UTC; 15s ago
 Main PID: 23294 (openvpn)
   Status: "Pre-connection initialization successful"
    Tasks: 1 (limit: 2749)
   Memory: 1.5M
   CGroup: /system.slice/system-openvpn.slice/openvpn@server.service
           └─23294 /usr/sbin/openvpn --cd /etc/openvpn/ --config server.conf

May 19 12:27:02 server.loc systemd[1]: Starting OpenVPN Tunneling Application O>
May 19 12:27:02 server.loc systemd[1]: Started OpenVPN Tunneling Application On>
```

#### 4. Настройка openvpn клиента.
Cоздаём конфигурационный файл клиента    
```
vi /etc/openvpn/server.conf

dev tap
remote 192.168.56.10
ifconfig 10.10.10.2 255.255.255.0
topology subnet
route 192.168.56.0 255.255.255.0
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```
● На сервер клиента в директорию ``/etc/openvpn`` необходимо скопировать файл-ключ ``static.key``, который был создан на сервере.    
● Запускаем openvpn клиент и добавляем в автозагрузку    
```
systemctl start openvpn@server
systemctl enable openvpn@server
```
#### 5. Далее необходимо замерить скорость в туннеле.
● на openvpn сервере запускаем iperf3 в режиме сервера iperf3 -s &    
```
iperf3 -s &
[1] 23998
[root@server ~]# -----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
Accepted connection from 10.10.10.2, port 35214
[  5] local 10.10.10.1 port 5201 connected to 10.10.10.2 port 35216
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec  9.45 MBytes  78.9 Mbits/sec                  
[  5]   1.00-2.00   sec  10.0 MBytes  83.9 Mbits/sec                  
[  5]   2.00-3.00   sec  4.51 MBytes  38.0 Mbits/sec                  
[  5]   3.00-4.00   sec  4.07 MBytes  34.2 Mbits/sec                  
[  5]   4.00-5.00   sec  5.19 MBytes  43.5 Mbits/sec                  
[  5]   5.00-6.00   sec  5.64 MBytes  47.3 Mbits/sec                  
[  5]   6.00-7.00   sec  5.79 MBytes  48.6 Mbits/sec                  
[  5]   7.00-8.00   sec  6.50 MBytes  54.5 Mbits/sec                  
[  5]   8.00-9.01   sec  6.97 MBytes  58.0 Mbits/sec                  
[  5]   9.01-10.00  sec  6.39 MBytes  54.1 Mbits/sec                  
[  5]  10.00-11.00  sec  6.87 MBytes  57.6 Mbits/sec                  
[  5]  11.00-12.00  sec  7.06 MBytes  59.1 Mbits/sec                  
[  5]  12.00-13.00  sec  7.49 MBytes  62.9 Mbits/sec                  
[  5]  13.00-14.01  sec  7.67 MBytes  63.9 Mbits/sec                  
[  5]  14.01-15.01  sec  7.67 MBytes  64.6 Mbits/sec                  
[  5]  15.01-16.00  sec  4.41 MBytes  37.2 Mbits/sec                  
[  5]  16.00-17.01  sec  8.56 MBytes  71.2 Mbits/sec                  
[  5]  17.01-18.00  sec  9.74 MBytes  82.0 Mbits/sec                  
[  5]  18.00-19.00  sec  9.65 MBytes  81.2 Mbits/sec                  
[  5]  19.00-20.01  sec  5.26 MBytes  43.9 Mbits/sec                  
[  5]  20.01-21.00  sec  2.30 MBytes  19.4 Mbits/sec                  
[  5]  21.00-22.00  sec  6.64 MBytes  55.7 Mbits/sec
[  5]  22.00-23.00  sec  6.84 MBytes  57.4 Mbits/sec                  
[  5]  23.00-24.00  sec  5.88 MBytes  49.3 Mbits/sec                  
[  5]  24.00-25.00  sec  5.92 MBytes  49.7 Mbits/sec                  
[  5]  25.00-26.00  sec  5.90 MBytes  49.5 Mbits/sec                  
[  5]  26.00-27.00  sec  4.76 MBytes  39.9 Mbits/sec                  
[  5]  27.00-28.00  sec  6.63 MBytes  55.6 Mbits/sec                  
[  5]  28.00-29.00  sec  7.05 MBytes  59.1 Mbits/sec                  
[  5]  29.00-30.00  sec  5.92 MBytes  49.6 Mbits/sec                  
[  5]  30.00-31.00  sec  6.67 MBytes  55.9 Mbits/sec                  
[  5]  31.00-32.00  sec  5.95 MBytes  49.9 Mbits/sec                  
[  5]  32.00-33.00  sec  5.68 MBytes  47.7 Mbits/sec                  
[  5]  33.00-34.00  sec  7.31 MBytes  61.1 Mbits/sec                  
[  5]  34.00-35.00  sec  5.91 MBytes  49.8 Mbits/sec                  
[  5]  35.00-36.00  sec  5.84 MBytes  49.0 Mbits/sec                  
[  5]  36.00-37.00  sec  5.87 MBytes  49.3 Mbits/sec                  
[  5]  37.00-38.00  sec  5.22 MBytes  43.8 Mbits/sec                  
[  5]  38.00-39.00  sec  5.52 MBytes  46.3 Mbits/sec                  
[  5]  39.00-40.00  sec  5.71 MBytes  47.8 Mbits/sec                  
[  5]  40.00-40.04  sec   157 KBytes  34.1 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-40.04  sec   257 MBytes  53.8 Mbits/sec                  receiver
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------  
```
● на openvpn клиенте запускаем iperf3 в режиме клиента и замеряем скорость в туннеле    
```
iperf3 -c 10.10.10.1 -t 40 -i 5 
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 35216 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.00   sec  33.6 MBytes  56.3 Mbits/sec   16    102 KBytes       
[  5]   5.00-10.01  sec  31.3 MBytes  52.4 Mbits/sec   11    106 KBytes       
[  5]  10.01-15.01  sec  36.9 MBytes  61.9 Mbits/sec   13    116 KBytes       
[  5]  15.01-20.00  sec  37.4 MBytes  62.9 Mbits/sec   20   96.8 KBytes       
[  5]  20.00-25.00  sec  27.7 MBytes  46.5 Mbits/sec   13    111 KBytes       
[  5]  25.00-30.00  sec  30.3 MBytes  50.9 Mbits/sec   15    108 KBytes       
[  5]  30.00-35.01  sec  31.4 MBytes  52.6 Mbits/sec   11    115 KBytes       
[  5]  35.01-40.01  sec  28.3 MBytes  47.5 Mbits/sec   12   98.0 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-40.01  sec   257 MBytes  53.9 Mbits/sec  111             sender
[  5]   0.00-40.04  sec   257 MBytes  53.8 Mbits/sec                  receiver

iperf Done.
```

#### 6. Повторяем пункты 1-5 для режима работы tun. 
Конфигарационные файлы сервера и клиента изменятся только в директиве dev. Делаем выводы о режимах, их достоинствах и недостатках.    

``ТУНЕЛЬ``    

● на openvpn сервере запускаем iperf3 в режиме сервера iperf3 -s &    
```
iperf3 -s &
Accepted connection from 10.10.10.2, port 35218
[  5] local 10.10.10.1 port 5201 connected to 10.10.10.2 port 35220
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec  5.42 MBytes  45.4 Mbits/sec                  
[  5]   1.00-2.00   sec  5.54 MBytes  46.5 Mbits/sec                  
[  5]   2.00-3.01   sec  7.63 MBytes  63.5 Mbits/sec                  
[  5]   3.01-4.01   sec  7.41 MBytes  62.3 Mbits/sec                  
[  5]   4.01-5.00   sec  10.2 MBytes  85.4 Mbits/sec                  
[  5]   5.00-6.00   sec  8.63 MBytes  72.5 Mbits/sec                  
[  5]   6.00-7.01   sec  7.85 MBytes  65.6 Mbits/sec                  
[  5]   7.01-8.00   sec  10.1 MBytes  84.9 Mbits/sec                  
[  5]   8.00-9.00   sec  5.66 MBytes  47.4 Mbits/sec                  
[  5]   9.00-10.00  sec  5.82 MBytes  48.8 Mbits/sec                  
[  5]  10.00-11.00  sec  9.22 MBytes  77.3 Mbits/sec                  
[  5]  11.00-12.00  sec  8.73 MBytes  73.3 Mbits/sec                  
[  5]  12.00-13.00  sec  5.49 MBytes  46.0 Mbits/sec                  
[  5]  13.00-14.00  sec  4.55 MBytes  38.2 Mbits/sec                  
[  5]  14.00-15.00  sec  6.30 MBytes  52.6 Mbits/sec                  
[  5]  15.00-16.00  sec  7.17 MBytes  60.4 Mbits/sec                  
[  5]  16.00-17.00  sec  6.41 MBytes  53.7 Mbits/sec                  
[  5]  17.00-18.00  sec  8.71 MBytes  73.1 Mbits/sec                  
[  5]  18.00-19.01  sec  6.91 MBytes  57.4 Mbits/sec                  
[  5]  19.01-20.00  sec  6.19 MBytes  52.4 Mbits/sec                  
[  5]  19.01-20.00  sec  6.19 MBytes  52.4 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-20.00  sec   149 MBytes  62.4 Mbits/sec                  receiver
iperf3: the client has terminated
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
```
● на openvpn клиенте запускаем iperf3 в режиме клиента и замеряем скорость в туннеле    
```
iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 35220 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.00   sec  36.4 MBytes  61.0 Mbits/sec   19    107 KBytes       
[  5]   5.00-10.01  sec  38.2 MBytes  64.0 Mbits/sec   14   87.2 KBytes       
[  5]  10.01-15.00  sec  34.1 MBytes  57.3 Mbits/sec    7    112 KBytes       
[  5]  15.00-20.01  sec  35.6 MBytes  59.6 Mbits/sec   15    112 KBytes       
[  5]  20.01-20.80  sec  4.77 MBytes  50.6 Mbits/sec    1    108 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-20.80  sec   149 MBytes  60.1 Mbits/sec   56             sender
[  5]   0.00-20.80  sec  0.00 Bytes  0.00 bits/sec                  receiver
```

### 2. Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на виртуалку.


#### 1. Устанавливаем репозиторий EPEL.
`` yum install -y epel-release``    
#### 2. Устанавливаем необходимые пакеты.
`` yum install -y openvpn easy-rsa``
#### 3. Переходим в директорию /etc/openvpn/ и инициализируем pki
```
 cd /etc/openvpn/
 /usr/share/easy-rsa/3.0.8/easyrsa init-pki
``` 
#### 4. Сгенерируем необходимые ключи и сертификаты для сервера
```
echo 'rasvpn' | /usr/share/easy-rsa/3.0.8/easyrsa build-ca nopass
echo 'rasvpn' | /usr/share/easy-rsa/3.0.8/easyrsa gen-req server nopass
echo 'yes' | /usr/share/easy-rsa/3.0.8/easyrsa sign-req server server
/usr/share/easy-rsa/3.0.8/easyrsa gen-dh
openvpn --genkey --secret ca.key
```
Версия easy-rsa может отличаться, посмотреть актуальную версию можно так:    
``rpm -qa | grep easy-rsa easy-rsa-3.0.8-1.el8.noarch``    

#### 5. Сгенерируем сертификаты для клиента.
```
echo 'client' | /usr/share/easy-rsa/3/easyrsa gen-req client nopass
echo 'yes' | /usr/share/easy-rsa/3/easyrsa sign-req client client
```

#### 6. Создадим конфигурационный файл /etc/openvpn/server.conf
```   
server.conf >
port 1207
proto udp
dev tun
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/server.crt
key /etc/openvpn/pki/private/server.key
dh /etc/openvpn/pki/dh.pem
server 10.10.10.0 255.255.255.0
ifconfig-pool-persist ipp.txt
client-to-client
client-config-dir /etc/openvpn/client
keepalive 10 120
comp-lzo
persist-key
persist-tun
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```

#### 7. Зададим параметр iroute для клиента

``echo 'iroute 10.10.10.0 255.255.255.0' > /etc/openvpn/client/client``

#### 8. Запускаем openvpn сервер и добавляем его в автозагрузку
```
systemctl start openvpn@server
systemctl enable openvpn@server
```

#### 9. Скопируем следующие файлы сертификатов и ключ для клиента на хост-машину.
```
/etc/openvpn/pki/ca.crt
/etc/openvpn/pki/issued/client.crt
/etc/openvpn/pki/private/client.key
(файлы рекомендуется расположить в той же директории, что и client.conf)
```
#### 10. Создадим конфигурационны файл клиента client.conf на хост-машине
```
client.conf >
dev tun
proto udp
remote 192.168.56.10 1207
client
resolv-retry infinite
remote-cert-tls server
ca ./ca.crt
cert ./client.crt
key ./client.key
route 192.168.56.0 255.255.255.0
persist-key
persist-tun
comp-lzo
verb 3
```

В этом конфигурационном файле указано, что файлы сертификатов располагаются в директории, где располагается client.conf. При желании можно разместить сертификаты в других директориях и в конфиге
скорректировать пути.    


#### 11.  После того, как все готово, подключаемся к openvpn сервер с хост-машины.
``sudo openvpn --config client.conf``

#### 12. При успешном подключении проверяем пинг по внутреннему IP адресу

сервера в туннеле. ``ping -c 4 10.10.10.1``    
#### 13. Также проверяем командой ip r (netstat -rn) на хостовой машине
что сеть туннеля импортирована в таблицу маршрутизации.    