Цель домашнего задания
----------------------
Создать домашнюю сетевую лабораторию. Научится настраивать протокол OSPF в Linux-based системах.


Описание домашнего задания
--------------------------
```
1. Развернуть 3 виртуальные машины
2. Объединить их разными vlan
    - настроить OSPF между машинами на базе Quagga;
    - изобразить ассиметричный роутинг;
    - сделать один из линков "дорогим", но что бы при этом роутинг был симметричным.
```

### 1. Развернуть 3 виртуальные машины

Так как мы планируем настроить OSPF, все 3 виртуальные машины должны быть соединены между собой (разными VLAN), а также иметь одну (или несколько) доолнительных сетей, к которым, далее OSPF сформирует маршруты.    
Создаём каталог, в котором будут храниться настройки виртуальной машины. В каталоге создаём файл с именем Vagrantfile, добавляем в него следующее содержимое:    
```
MACHINES = {
  :router1 => {
        :box_name => "ubuntu/focal64",
        :vm_name => "router1",
        :net => [
                   {ip: '10.0.10.1', adapter: 2, netmask: "255.255.255.252", virtualbox__intnet: "r1-r2"},
                   {ip: '10.0.12.1', adapter: 3, netmask: "255.255.255.252", virtualbox__intnet: "r1-r3"},
                   {ip: '192.168.10.1', adapter: 4, netmask: "255.255.255.0", virtualbox__intnet: "net1"},
                   {ip: '192.168.50.10', adapter: 5},
                ]
  },

  :router2 => {
        :box_name => "ubuntu/focal64",
        :vm_name => "router2",
        :net => [
                   {ip: '10.0.10.2', adapter: 2, netmask: "255.255.255.252", virtualbox__intnet: "r1-r2"},
                   {ip: '10.0.11.2', adapter: 3, netmask: "255.255.255.252", virtualbox__intnet: "r2-r3"},
                   {ip: '192.168.20.1', adapter: 4, netmask: "255.255.255.0", virtualbox__intnet: "net2"},
                   {ip: '192.168.50.11', adapter: 5},
                ]
  },

  :router3 => {
        :box_name => "ubuntu/focal64",
        :vm_name => "router3",
        :net => [
                   {ip: '10.0.11.1', adapter: 2, netmask: "255.255.255.252", virtualbox__intnet: "r2-r3"},
                   {ip: '10.0.12.2', adapter: 3, netmask: "255.255.255.252", virtualbox__intnet: "r1-r3"},
                   {ip: '192.168.30.1', adapter: 4, netmask: "255.255.255.0", virtualbox__intnet: "net3"},
                   {ip: '192.168.50.12', adapter: 5},
                ]
  }

}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|
    
    config.vm.define boxname do |box|
   
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxconfig[:vm_name]

      if boxconfig[:vm_name] == "router3"
       box.vm.provision "ansible" do |ansible|
        ansible.playbook = "ansible/provision.yml"
        ansible.inventory_path = "ansible/hosts"
        ansible.host_key_checking = "false"
        ansible.limit = "all"
       end
      end

      boxconfig[:net].each do |ipconf|
        box.vm.network "private_network", ipconf
      end

     end
  end
end
```
В данный Vagrantfile уже добавлен модуль запуска Ansible-playbook.
После создания данного файла, из терминала идём в каталог, в котором лежит данный Vagrantfile и вводим команду ``vagrant up``    
Результатом выполнения данной команды будут 3 созданные виртуальные машины, которые соединены между собой сетями (``10.0.10.0/30, 10.0.11.0/30 и 10.0.12.0/30``). У каждого роутера есть дополнительная сеть:    
на router1 — 192.168.10.0/24    
на router2 — 192.168.20.0/24    
на router3 — 192.168.30.0/24    
На данном этапе ping до дополнительных сетей (192.168.10-30.0/24) с соседних роутеров будет недоступен.    
Для подключения к ВМ нужно ввести команду ``**vagrant ssh <имя машины>**``, например ``**vagrant ssh router1**``    
Далее потребуется переключиться в root пользователя: ``sudo -i``


### Установка пакетов для тестирования и настройки OSPF
---------------------------------------------------

Перед настройкой ``FRR`` рекомендуется поставить базовые программы для изменения конфигурационных файлов (vim) и изучения сети (``traceroute, tcpdump, net-tools``):    
```
apt update
apt install vim traceroute tcpdump net-tools
```
### 2.1 Настройка OSPF между машинами на базе Quagga

В данном руководстве настойка OSPF будет осуществляться в ``FRR``.    
Процесс установки ``FRR`` и настройки ``OSPF`` вручную:

#### 1) Отключаем файерволл ufw и удаляем его из автозагрузки:
```
   systemctl stop ufw 
   systemctl disable ufw
```
#### 2) Добавляем gpg ключ:
   ``**curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add -**``

#### 3) Добавляем репозиторий c пакетом FRR:
   ``echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) frr-stable > /etc/apt/sources.list.d/frr.list``

#### 4) Обновляем пакеты и устанавливаем FRR:
```   sudo apt update
   sudo apt install frr frr-pythontools
```

#### 5) Разрешаем (включаем) маршрутизацию транзитных пакетов:
``sysctl net.ipv4.conf.all.forwarding=1``

#### 6) Включаем демон ospfd в FRR

Для этого открываем в редакторе файл ``/etc/frr/daemons`` и меняем в нём параметры для пакетов ``zebra и ospfd на yes``:
```
vim /etc/frr/daemons
``zebra=yes``
``ospfd=yes``
bgpd=no
ospf6d=no
ripd=no
ripngd=no
isisd=no
pimd=no
ldpd=no
nhrpd=no
eigrpd=no
babeld=no
sharpd=no
pbrd=no
bfdd=no
fabricd=no
vrrpd=no
pathd=no
```

#### 7) Настройка OSPF

Для настройки OSPF нам потребуется создать файл ``/etc/frr/frr.conf`` который будет содержать в себе информацию о требуемых интерфейсах и ``OSPF``. Разберем пример создания файла на хосте ``router1``.    
Для начала нам необходимо узнать имена интерфейсов и их адреса.    
Сделать это можно с помощью двух способов:    

Посмотреть в linux: ``ip a | grep inet``    
```
root@router1:~# ip a | grep "inet " 
    inet 127.0.0.1/8 scope host lo
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic enp0s3
    inet 10.0.10.1/30 brd 10.0.10.3 scope global enp0s8
    inet 10.0.12.1/30 brd 10.0.12.3 scope global enp0s9
    inet 192.168.10.1/24 brd 192.168.10.255 scope global enp0s10
    inet 192.168.50.10/24 brd 192.168.50.255 scope global enp0s16
root@router1:~# 
```
Зайти в интерфейс ``FRR`` и посмотреть информацию об интерфейсах
```
root@router1:~# vtysh
Hello, this is FRRouting (version 8.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.
router1# show interface brief
Interface       Status  VRF             Addresses
---------       ------  ---             ---------
enp0s3          up      default         10.0.2.15/24
enp0s8          up      default         10.0.10.1/30
enp0s9          up      default         10.0.12.1/30
enp0s10         up      default         192.168.10.1/24
enp0s16         up      default         192.168.50.10/24
lo              up      default         

router1# exit 
```
 
В обоих примерах мы увидем имена сетевых интерфейсов, их ip-адреса и маски подсети. Исходя из схемы мы понимаем, что для настройки OSPF нам достаточно описать интерфейсы ``enp0s8, enp0s9, enp0s10``    
Создаём файл ``/etc/frr/frr.conf`` и вносим в него следующую информацию:    
```
!Указание версии FRR
frr version 8.1
frr defaults traditional
!Указываем имя машины
hostname router1
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
!Добавляем информацию об интерфейсе enp0s8
interface enp0s8
 !Указываем имя интерфейса
 description r1-r2
 !Указываем ip-aдрес и маску (эту информацию мы получили в прошлом шаге)
 ip address 10.0.10.1/30
 !Указываем параметр игнорирования MTU
 ip ospf mtu-ignore
 !Если потребуется, можно указать «стоимость» интерфейса
 !ip ospf cost 1000
 !Указываем параметры hello-интервала для OSPF пакетов
 ip ospf hello-interval 10
 !Указываем параметры dead-интервала для OSPF пакетов
 !Должно быть кратно предыдущему значению
 ip ospf dead-interval 30
!
interface enp0s9
 description r1-r3
 ip address 10.0.12.1/30
 ip ospf mtu-ignore
 !ip ospf cost 45
 ip ospf hello-interval 10
 ip ospf dead-interval 30

interface enp0s10
 description net_router1
 ip address 192.168.10.1/24
 ip ospf mtu-ignore
 !ip ospf cost 45
 ip ospf hello-interval 10
 ip ospf dead-interval 30 
!
!Начало настройки OSPF
router ospf
 !Указываем router-id 
 router-id 1.1.1.1
 !Указываем сети, которые хотим анонсировать соседним роутерам
 network 10.0.10.0/30 area 0
 network 10.0.12.0/30 area 0
 network 192.168.10.0/24 area 0 
 !Указываем адреса соседних роутеров
 neighbor 10.0.10.2
 neighbor 10.0.12.2

!Указываем адрес log-файла
log file /var/log/frr/frr.log
default-information originate always
```

После создания файлов ``/etc/frr/frr.conf и /etc/frr/daemons`` нужно проверить, что владельцем файла является пользователь ``frr``. Группа файла также должна быть ``frr``. Должны быть установленны следующие права:    
у владельца на чтение и запись    
у группы только на чтение    
ls -l /etc/frr    
Если права или владелец файла указан неправильно, то нужно поменять владельца и назначить правильные права, например:    
```
chown frr:frr /etc/frr/frr.conf 
chmod 640 /etc/frr/frr.conf 
```

Перезапускаем FRR и добавляем его в автозагрузку    
```
   systemct restart frr 
   systemctl enable frr
```
Сохраняем изменения и выходим из данного файла. 
```
systemctl status frr
● frr.service - FRRouting
     Loaded: loaded (/lib/systemd/system/frr.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2022-02-23 15:24:04 UTC; 2h 1min ago
       Docs: https://frrouting.readthedocs.io/en/latest/setup.html
    Process: 31988 ExecStart=/usr/lib/frr/frrinit.sh start (code=exited, status=0/SUCCESS)
   Main PID: 32000 (watchfrr)
     Status: "FRR Operational"
      Tasks: 9 (limit: 1136)
     Memory: 13.2M
     CGroup: /system.slice/frr.service
             ├─32000 /usr/lib/frr/watchfrr -d -F traditional zebra ospfd staticd
             ├─32016 /usr/lib/frr/zebra -d -F traditional -A 127.0.0.1 -s 90000000
             ├─32021 /usr/lib/frr/ospfd -d -F traditional -A 127.0.0.1
             └─32024 /usr/lib/frr/staticd -d -F traditional -A 127.0.0.1

Feb 23 15:23:59 router1 zebra[32016]: [VTVCM-Y2NW3] Configuration Read in Took: 00:00:00
Feb 23 15:23:59 router1 ospfd[32021]: [VTVCM-Y2NW3] Configuration Read in Took: 00:00:00
Feb 23 15:23:59 router1 staticd[32024]: [VTVCM-Y2NW3] Configuration Read in Took: 00:00:00
Feb 23 15:24:04 router1 watchfrr[32000]: [QDG3Y-BY5TN] staticd state -> up : connect succeeded
Feb 23 15:24:04 router1 watchfrr[32000]: [QDG3Y-BY5TN] zebra state -> up : connect succeeded
Feb 23 15:24:04 router1 watchfrr[32000]: [QDG3Y-BY5TN] ospfd state -> up : connect succeeded
Feb 23 15:24:04 router1 watchfrr[32000]: [KWE5Q-QNGFC] all daemons up, doing startup-complete notify
Feb 23 15:24:04 router1 frrinit.sh[31988]:  * Started watchfrr
Feb 23 15:24:04 router1 systemd[1]: Started FRRouting.
```

Так же все прописывается на 2 других роутерах.

Вывод с Router1
---------------

```
sh ip route ospf 
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

O   10.0.10.0/30 [110/100] is directly connected, enp0s8, weight 1, 00:38:52
O>* 10.0.11.0/30 [110/200] via 10.0.10.2, enp0s8, weight 1, 00:34:34
  *                        via 10.0.12.2, enp0s9, weight 1, 00:34:34
O   10.0.12.0/30 [110/100] is directly connected, enp0s9, weight 1, 00:34:34
O   192.168.10.0/24 [110/100] is directly connected, enp0s10, weight 1, 00:40:18
O>* 192.168.20.0/24 [110/200] via 10.0.10.2, enp0s8, weight 1, 00:38:43
O>* 192.168.30.0/24 [110/200] via 10.0.12.2, enp0s9, weight 1, 00:34:34
```
```
root@router1:/etc/frr# ping -c4 192.168.20.1
PING 192.168.20.1 (192.168.20.1) 56(84) bytes of data.
64 bytes from 192.168.20.1: icmp_seq=1 ttl=64 time=0.706 ms
64 bytes from 192.168.20.1: icmp_seq=2 ttl=64 time=0.711 ms
64 bytes from 192.168.20.1: icmp_seq=3 ttl=64 time=0.762 ms
64 bytes from 192.168.20.1: icmp_seq=4 ttl=64 time=0.671 ms

--- 192.168.20.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3054ms
rtt min/avg/max/mdev = 0.671/0.712/0.762/0.032 ms
root@router1:/etc/frr# ping -c4 192.168.30.1
PING 192.168.30.1 (192.168.30.1) 56(84) bytes of data.
64 bytes from 192.168.30.1: icmp_seq=1 ttl=64 time=0.857 ms
64 bytes from 192.168.30.1: icmp_seq=2 ttl=64 time=0.742 ms
64 bytes from 192.168.30.1: icmp_seq=3 ttl=64 time=0.659 ms
64 bytes from 192.168.30.1: icmp_seq=4 ttl=64 time=0.772 ms

--- 192.168.30.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3067ms
rtt min/avg/max/mdev = 0.659/0.757/0.857/0.070 ms
```
```
Попробуем отключить интерфейс ``enp0s9`` и немного подождем и снова запустим трассировку до ip-адреса    ``192.168.30.1``    
root@router1:~# ifconfig enp0s9 down
root@router1:~# ip a | grep enp0s9 
4: enp0s9: <BROADCAST,MULTICAST> mtu 1500 qdisc fq_codel state DOWN group default qlen 1000
root@router1:~# traceroute 192.168.30.1
traceroute to 192.168.30.1 (192.168.30.1), 30 hops max, 60 byte packets
 1  10.0.10.2 (10.0.10.2)  0.522 ms  0.479 ms  0.460 ms
 2  192.168.30.1 (192.168.30.1)  0.796 ms  0.777 ms  0.644 ms
```
Вывод с Router2 
---------------

```
router2# show ip route ospf 
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

O   10.0.10.0/30 [110/100] is directly connected, enp0s8, weight 1, 00:43:56
O   10.0.11.0/30 [110/100] is directly connected, enp0s9, weight 1, 00:43:56
O>* 10.0.12.0/30 [110/200] via 10.0.10.1, enp0s8, weight 1, 00:39:34
  *                        via 10.0.11.1, enp0s9, weight 1, 00:39:34
O>* 192.168.10.0/24 [110/200] via 10.0.10.1, enp0s8, weight 1, 00:43:50
O   192.168.20.0/24 [110/100] is directly connected, enp0s10, weight 1, 00:43:56
O>* 192.168.30.0/24 [110/200] via 10.0.11.1, enp0s9, weight 1, 00:43:40
```
```
root@router2:~# ping -c4 192.168.10.1
PING 192.168.10.1 (192.168.10.1) 56(84) bytes of data.
64 bytes from 192.168.10.1: icmp_seq=1 ttl=64 time=1.58 ms
64 bytes from 192.168.10.1: icmp_seq=2 ttl=64 time=0.739 ms
64 bytes from 192.168.10.1: icmp_seq=3 ttl=64 time=0.798 ms
64 bytes from 192.168.10.1: icmp_seq=4 ttl=64 time=0.836 ms

--- 192.168.10.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3114ms
rtt min/avg/max/mdev = 0.739/0.987/1.577/0.342 ms
root@router2:~# ping -c4 192.168.30.1
PING 192.168.30.1 (192.168.30.1) 56(84) bytes of data.
64 bytes from 192.168.30.1: icmp_seq=1 ttl=64 time=1.18 ms
64 bytes from 192.168.30.1: icmp_seq=2 ttl=64 time=0.637 ms
64 bytes from 192.168.30.1: icmp_seq=3 ttl=64 time=0.667 ms
64 bytes from 192.168.30.1: icmp_seq=4 ttl=64 time=0.974 ms

--- 192.168.30.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3063ms
rtt min/avg/max/mdev = 0.637/0.865/1.182/0.225 ms
```
Вывод с Router3 
---------------

```
sh ip route ospf 
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

O>* 10.0.10.0/30 [110/200] via 10.0.11.2, enp0s8, weight 1, 00:42:21
  *                        via 10.0.12.1, enp0s9, weight 1, 00:42:21
O   10.0.11.0/30 [110/100] is directly connected, enp0s8, weight 1, 00:46:43
O   10.0.12.0/30 [110/100] is directly connected, enp0s9, weight 1, 00:48:09
O>* 192.168.10.0/24 [110/200] via 10.0.12.1, enp0s9, weight 1, 00:42:21
O>* 192.168.20.0/24 [110/200] via 10.0.11.2, enp0s8, weight 1, 00:46:34
O   192.168.30.0/24 [110/100] is directly connected, enp0s10, weight 1, 00:49:37
```
```
root@router3:~# ping -c4 192.168.10.1
PING 192.168.10.1 (192.168.10.1) 56(84) bytes of data.
64 bytes from 192.168.10.1: icmp_seq=1 ttl=64 time=1.16 ms
64 bytes from 192.168.10.1: icmp_seq=2 ttl=64 time=0.783 ms
64 bytes from 192.168.10.1: icmp_seq=3 ttl=64 time=0.692 ms
64 bytes from 192.168.10.1: icmp_seq=4 ttl=64 time=0.611 ms

--- 192.168.10.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 0.611/0.812/1.163/0.211 ms
root@router3:~# ping -c4 192.168.20.1
PING 192.168.20.1 (192.168.20.1) 56(84) bytes of data.
64 bytes from 192.168.20.1: icmp_seq=1 ttl=64 time=2.48 ms
64 bytes from 192.168.20.1: icmp_seq=2 ttl=64 time=0.630 ms
64 bytes from 192.168.20.1: icmp_seq=3 ttl=64 time=3.19 ms
64 bytes from 192.168.20.1: icmp_seq=4 ttl=64 time=1.29 ms

--- 192.168.20.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3018ms
rtt min/avg/max/mdev = 0.630/1.895/3.187/0.997 ms
```

### 2.2 Настройка ассиметричного роутинга

Для настройки ассиметричного роутинга нам необходимо выключить блокировку ассиметричной маршрутизации:     ``sysctl net.ipv4.conf.all.rp_filter=0``    

Далее, выбираем один из роутеров, на котором изменим «стоимость интерфейса». Например поменяем стоимость интерфейса ``enp0s8 на router1``:    
```
root@router1:~# vtysh

Hello, this is FRRouting (version 8.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router1# conf t
router1(config)# int enp0s8 
router1(config-if)# ip ospf cost 1000
router1(config-if)# exit
router1(config)# exit
router1# show ip route ospf
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

O   10.0.10.0/30 [110/300] via 10.0.12.2, enp0s9, weight 1, 00:02:24
O>* 10.0.11.0/30 [110/200] via 10.0.12.2, enp0s9, weight 1, 00:02:29
O   10.0.12.0/30 [110/100] is directly connected, enp0s9, weight 1, 00:02:29
O   192.168.10.0/24 [110/100] is directly connected, enp0s10, weight 1, 00:03:04
O>* 192.168.20.0/24 [110/300] via 10.0.12.2, enp0s9, weight 1, 00:02:24
O>* 192.168.30.0/24 [110/200] via 10.0.12.2, enp0s9, weight 1, 00:02:29
router1# 
```
```
router2# show ip route ospf 
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

O   10.0.10.0/30 [110/100] is directly connected, enp0s8, weight 1, 00:00:09
O   10.0.11.0/30 [110/100] is directly connected, enp0s9, weight 1, 00:34:11
O>* 10.0.12.0/30 [110/200] via 10.0.10.1, enp0s8, weight 1, 00:00:09
  *                        via 10.0.11.1, enp0s9, weight 1, 00:00:09
O>* 192.168.10.0/24 [110/200] via 10.0.10.1, enp0s8, weight 1, 00:00:09
O   192.168.20.0/24 [110/100] is directly connected, enp0s10, weight 1, 00:34:11
O>* 192.168.30.0/24 [110/200] via 10.0.11.1, enp0s9, weight 1, 00:33:36
router2# 
```

После внесения данных настроек, мы видим, что маршрут до сети ``192.168.20.0/30``  теперь пойдёт через ``router2``, но обратный трафик от ``router2`` пойдёт по другому пути. Давайте это проверим:    

##### 1) На router1 запускаем пинг от 192.168.10.1 до 192.168.20.1: 
``ping -I 192.168.10.1 192.168.20.1``

##### 2) На router2 запускаем tcpdump, который будет смотреть трафик только на порту enp0s9:
```
root@router2:~# tcpdump -i enp0s9
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on enp0s9, link-type EN10MB (Ethernet), capture size 262144 bytes
19:03:00.185258 IP 192.168.10.1 > router2: ICMP echo request, id 6, seq 108, length 64
19:03:01.186977 IP 192.168.10.1 > router2: ICMP echo request, id 6, seq 109, length 64
19:03:02.188563 IP 192.168.10.1 > router2: ICMP echo request, id 6, seq 110, length 64
19:03:02.540289 IP router2 > ospf-all.mcast.net: OSPFv2, Hello, length 48
19:03:02.542198 IP 10.0.11.1 > ospf-all.mcast.net: OSPFv2, Hello, length 48
19:03:03.189952 IP 192.168.10.1 > router2: ICMP echo request, id 6, seq 111, length 64
Видим что данный порт только получает ICMP-трафик с адреса 192.168.10.1
```

##### 3) На router2 запускаем tcpdump, который будет смотреть трафик только на порту enp0s8:
```
root@router2:~# tcpdump -i enp0s8
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on enp0s8, link-type EN10MB (Ethernet), capture size 262144 bytes
19:05:24.410547 IP router2 > 192.168.10.1: ICMP echo reply, id 6, seq 248, length 64
19:05:25.461411 IP router2 > 192.168.10.1: ICMP echo reply, id 6, seq 249, length 64
19:05:26.496036 IP router2 > 192.168.10.1: ICMP echo reply, id 6, seq 250, length 64
19:05:27.498524 IP router2 > 192.168.10.1: ICMP echo reply, id 6, seq 251, length 64
Видим что данный порт только отправляет ICMP-трафик на адрес 192.168.10.1
Таким образом мы видим ассиметричный роутинг.
```

### 2.3 Настройка симметричного роутинга

Так как у нас уже есть один «дорогой» интерфейс, нам потребуется добавить ещё один дорогой интерфейс, чтобы у нас перестала работать ассиметричная маршрутизация.    
Так как в прошлом задании мы заметили что router2 будет отправлять обратно трафик через порт enp0s8, мы также должны сделать его дорогим и далее проверить, что теперь используется симметричная маршрутизация:    
Поменяем стоимость интерфейса ``enp0s8 на router2:``    
```
router2# conf t
router2(config)# int enp0s8
router2(config-if)# ip ospf cost 1000
router2(config-if)# exit
router2(config)# exit
router2# 
router2# show ip route ospf
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

O   10.0.10.0/30 [110/1000] is directly connected, enp0s8, weight 1, 00:00:13
O   10.0.11.0/30 [110/100] is directly connected, enp0s9, weight 1, 00:29:53
O>* 10.0.12.0/30 [110/200] via 10.0.11.1, enp0s9, weight 1, 00:00:13
O>* 192.168.10.0/24 [110/300] via 10.0.11.1, enp0s9, weight 1, 00:00:13
O   192.168.20.0/24 [110/100] is directly connected, enp0s10, weight 1, 00:29:53
O>* 192.168.30.0/24 [110/200] via 10.0.11.1, enp0s9, weight 1, 00:29:18
router2# 
router2# exit 
root@router2:~# 
```
После внесения данных настроек, мы видим, что маршрут до сети ``192.168.10.0/30  пойдёт через router2``.    
Давайте это проверим:    
```
1) На router1 запускаем пинг от 192.168.10.1 до 192.168.20.1: 
ping -I 192.168.10.1 192.168.20.1

2) На router2 запускаем tcpdump, который будет смотреть трафик только на порту enp0s9:
root@router2:~# tcpdump -i enp0s9
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on enp0s9, link-type EN10MB (Ethernet), capture size 262144 bytes
19:30:28.551713 IP 192.168.10.1 > router2: ICMP echo request, id 6, seq 1737, length 64
19:30:28.551801 IP router2 > 192.168.10.1: ICMP echo reply, id 6, seq 1737, length 64
19:30:29.553801 IP 192.168.10.1 > router2: ICMP echo request, id 6, seq 1738, length 64
19:30:29.553927 IP router2 > 192.168.10.1: ICMP echo reply, id 6, seq 1738, length 64
19:30:30.555858 IP 192.168.10.1 > router2: ICMP echo request, id 6, seq 1739, length 64
19:30:30.555930 IP router2 > 192.168.10.1: ICMP echo reply, id 6, seq 1739, length 64
19:30:31.557504 IP 192.168.10.1 > router2: ICMP echo request, id 6, seq 1740, length 64
19:30:31.557573 IP router2 > 192.168.10.1: ICMP echo reply, id 6, seq 1740, length 64
19:30:32.559191 IP 192.168.10.1 > router2: ICMP echo request, id 6, seq 1741, length 64
19:30:32.559260 IP router2 > 192.168.10.1: ICMP echo reply, id 6, seq 1741, length 64

Теперь мы видим, что трафик между роутерами ходит симметрично.
```

