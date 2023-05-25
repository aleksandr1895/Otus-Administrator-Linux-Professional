Цель домашнего задания
----------------------
Научиться настраивать VLAN и LACP. 

Описание домашнего задания
--------------------------
```
в Office1 в тестовой подсети появляется сервера с доп интерфесами и адресами
в internal сети testLAN: 
- testClient1 - 10.10.10.254
- testClient2 - 10.10.10.254
- testServer1- 10.10.10.1 
- testServer2- 10.10.10.1

Равести вланами:
testClient1 <-> testServer1
testClient2 <-> testServer2

Между centralRouter и inetRouter "пробросить" 2 линка (общая inernal сеть) и объединить их в бонд, проверить работу c отключением интерфейсов
```

Инструкция по выполнению домашнего задания
------------------------------------------
Vagrant файл    
```
# -*- mode: ruby -*-
# vim: set ft=ruby :

MACHINES = {
  :inetRouter => {
        :box_name => "centos/stream8",
        :box_version => "20210210.0",
        :vm_name => "inetRouter",
        :net => [
                   {adapter: 2, auto_config: false, virtualbox__intnet: "router-net"},
                   {adapter: 3, auto_config: false, virtualbox__intnet: "router-net"},
                   {ip: '192.168.56.10', adapter: 8},
                ]
  },
  :centralRouter => {
        :box_name => "centos/stream8",
        :box_version => "20210210.0",
        :vm_name => "centralRouter",
        :net => [
                   {adapter: 2, auto_config: false, virtualbox__intnet: "router-net"},
                   {adapter: 3, auto_config: false, virtualbox__intnet: "router-net"},
                   {ip: '192.168.255.9', adapter: 6, netmask: "255.255.255.252", virtualbox__intnet: "office1-central"},
                   {ip: '192.168.56.11', adapter: 8},
                ]
  },

  :office1Router => {
        :box_name => "centos/stream8",
        :box_version => "20210210.0",
        :vm_name => "office1Router",
        :net => [
                   {ip: '192.168.255.10', adapter: 2, netmask: "255.255.255.252", virtualbox__intnet: "office1-central"},
                   {adapter: 3, auto_config: false, virtualbox__intnet: "vlan1"},
                   {adapter: 4, auto_config: false, virtualbox__intnet: "vlan1"},
                   {adapter: 5, auto_config: false, virtualbox__intnet: "vlan2"},
                   {adapter: 6, auto_config: false, virtualbox__intnet: "vlan2"},
                   {ip: '192.168.56.20', adapter: 8},
                ]
  },

  :testClient1 => {
        :box_name => "centos/stream8",
        :box_version => "20210210.0",
        :vm_name => "testClient1",
        :net => [
                   {adapter: 2, auto_config: false, virtualbox__intnet: "testLAN"},
                   {ip: '192.168.56.21', adapter: 8},
                ]
  },

  :testServer1 => {
        :box_name => "centos/stream8",
        :box_version => "20210210.0",
        :vm_name => "testServer1",
        :net => [
                   {adapter: 2, auto_config: false, virtualbox__intnet: "testLAN"},
                   {ip: '192.168.56.22', adapter: 8},
            ]
  },

  :testClient2 => {
        :box_name => "ubuntu/focal64",
        :box_version => "20220411.2.0",
        :vm_name => "testClient2",
        :net => [
                   {adapter: 2, auto_config: false, virtualbox__intnet: "testLAN"},
                   {ip: '192.168.56.31', adapter: 8},
                ]
  },

  :testServer2 => {
        :box_name => "ubuntu/focal64",
        :box_version => "20220411.2.0",
        :vm_name => "testServer2",
        :net => [
                   {adapter: 2, auto_config: false, virtualbox__intnet: "testLAN"},
                   {ip: '192.168.56.32', adapter: 8},
                ]
  },

}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|
    
    config.vm.define boxname do |box|
   
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxconfig[:vm_name]
      box.vm.box_version = boxconfig[:box_version]

      config.vm.provider "virtualbox" do |v|
        v.memory = 1024
        v.cpus = 2
       end

      if boxconfig[:vm_name] == "testServer2"
       box.vm.provision "ansible" do |ansible|
        ansible.playbook = "ansible/provision.yml"
        ansible.inventory_path = "ansible/hosts"
        ansible.host_key_checking = "false"
        ansible.become = "true"
        ansible.limit = "all"
       end
      end

      boxconfig[:net].each do |ipconf|
        box.vm.network "private_network", ipconf
      end

      box.vm.provision "shell", inline: <<-SHELL
        mkdir -p ~root/.ssh
        cp ~vagrant/.ssh/auth* ~root/.ssh
      SHELL
    end
  end
end
```

Данный Vagrantfile развернёт 7 виртаульных машин:    
5 ВМ на CentOS 8 Stream    
2 ВМ на Ubuntu 20.04    

Обратите внимание, что хосты ``testClient1, testServer1, testClient2 и testServer2`` находятся в одной сети (testLAN).    

Предварительная настройка хостов
--------------------------------

#### Перед настройкой VLAN и LACP рекомендуется установить на хосты следующие утилиты:    

```
vim traceroute tcpdump net-tools

Установка пакетов на CentOS 8 Stream: 
yum install -y vim traceroute tcpdump net-tools 

Установка пакетов на Ubuntu 20.04:
apt install -y vim traceroute tcpdump net-tools 
```
Настройка VLAN на хостах
------------------------
Настройка VLAN на RHEL-based системах:    

На хосте testClient1 требуется создать файл    
```
/etc/sysconfig/network-scripts/ifcfg-vlan1:
VLAN=yes
#Тип интерфеса - VLAN
TYPE=Vlan
#Указываем фиическое устройство, через которые будет работь VLAN
PHYSDEV=eth1
#Указываем номер VLAN (VLAN_ID)
VLAN_ID=1
VLAN_NAME_TYPE=DEV_PLUS_VID_NO_PAD
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
#Указываем IP-адрес интерфейса
IPADDR=10.10.10.254
#Указываем префикс (маску) подсети
PREFIX=24
#Указываем имя vlan
NAME=vlan1
#Указываем имя подинтерфейса
DEVICE=eth1.1
ONBOOT=yes
```

На хосте ``testServer1`` создадим идентичный файл с другим IP-адресом ``(10.10.10.1)``.    

После создания файлов нужно перезапустить сеть на обоих хостах:    
``systemctl restart NetworkManager``    

Проверим настройку интерфейса, если настройка произведена правильно, то с хоста ``testClient1`` будет проходить ping до хоста ``testServer1``:    
```
[vagrant@testClient1 ~]$ ip a 
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:03:15:fa brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic noprefixroute eth0
       valid_lft 80162sec preferred_lft 80162sec
    inet6 fe80::5054:ff:fe03:15fa/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:cb:35:ae brd ff:ff:ff:ff:ff:ff
    inet6 fe80::e1b1:ec7e:6337:dd54/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:91:64:3c brd ff:ff:ff:ff:ff:ff
    inet 192.168.56.21/24 brd 192.168.56.255 scope global noprefixroute eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe91:643c/64 scope link 
       valid_lft forever preferred_lft forever
5: eth1.1@eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 08:00:27:cb:35:ae brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.254/24 brd 10.10.10.255 scope global noprefixroute eth1.1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fecb:35ae/64 scope link 
       valid_lft forever preferred_lft forever
[vagrant@testClient1 ~]$ ping 10.10.10.254
PING 10.10.10.254 (10.10.10.254) 56(84) bytes of data.
64 bytes from 10.10.10.254: icmp_seq=1 ttl=64 time=0.081 ms
64 bytes from 10.10.10.254: icmp_seq=2 ttl=64 time=0.083 ms
64 bytes from 10.10.10.254: icmp_seq=3 ttl=64 time=0.082 ms
64 bytes from 10.10.10.254: icmp_seq=4 ttl=64 time=0.080 ms
^C
--- 10.10.10.254 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3056ms
rtt min/avg/max/mdev = 0.080/0.081/0.083/0.009 ms
[vagrant@testClient1 ~]$ 
```

#### Настройка VLAN на Ubuntu:

На хосте ``testClient2`` требуется создать файл    
```
/etc/netplan/50-cloud-init.yaml:
# This file is generated from information provided by the datasource.  Changes
# to it will not persist across an instance reboot.  To disable cloud-init's
# network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    version: 2
    ethernets:
        enp0s3:
            dhcp4: true
        #В разделе ethernets добавляем порт, на котором будем настраивать VLAN
        enp0s8: {}
    #Настройка VLAN
    vlans:
        #Имя VLANа
        vlan2:
          #Указываем номер VLAN`а
          id: 2
          #Имя физического интерфейса
          link: enp0s8
          #Отключение DHCP-клиента
          dhcp4: no
          #Указываем ip-адрес
          addresses: [10.10.10.254/24]
```
На хосте ``testServer2`` создадим идентичный файл с другим IP-адресом ``(10.10.10.1)``.    
После создания файлов нужно перезапустить сеть на обоих хостах:    
``netplan apply``    
После настройки второго VLAN`а ping должен работать между хостами testClient1, testServer1 и между хостами testClient2, testServer2.    
Примечание: до остальных хостов ping работать не будет, так как не настроена маршрутизация.    

Настройка LACP между хостами inetRouter и centralRouter
-------------------------------------------------------
Bond интерфейс будет работать через порты ``eth1 и eth2``.    
1) Изначально необходимо на обоих хостах добавить конфигурационные файлы для интерфейсов eth1 и eth2:   
```
vim /etc/sysconfig/network-scripts/ifcfg-eth1
#Имя физического интерфейса
DEVICE=eth1
#Включать интерфейс при запуске системы
ONBOOT=yes
#Отключение DHCP-клиента
BOOTPROTO=none
#Указываем, что порт часть bond-интерфейса
MASTER=bond0
#Указыаваем роль bond
SLAVE=yes
NM_CONTROLLED=yes
USERCTL=no
```
У интерфейса ifcfg-eth2 идентичный конфигурационный файл, в котором нужно изменить имя интерфейса. 
```
vim /etc/sysconfig/network-scripts/ifcfg-eth2
#Имя физического интерфейса
DEVICE=eth2
#Включать интерфейс при запуске системы
ONBOOT=yes
#Отключение DHCP-клиента
BOOTPROTO=none
#Указываем, что порт часть bond-интерфейса
MASTER=bond0
#Указыаваем роль bond
SLAVE=yes
NM_CONTROLLED=yes
USERCTL=no
```

2) После настройки интерфейсов eth1 и eth2 нужно настроить ``bond-интерфейс``, для этого создадим файл     ``/etc/sysconfig/network-scripts/ifcfg-bond0``    
```
vim /etc/sysconfig/network-scripts/ifcfg-bond0  
DEVICE=bond0
NAME=bond0
#Тип интерфейса — bond
TYPE=Bond
BONDING_MASTER=yes
#Указаваем IP-адрес 
IPADDR=192.168.255.1
#Указываем маску подсети
NETMASK=255.255.255.252
ONBOOT=yes
BOOTPROTO=static
#Указываем режим работы bond-интерфейса Active-Backup    
#fail_over_mac=1 — данная опция «разрешает отвалиться» одному интерфейсу    
BONDING_OPTS="mode=1 miimon=100 fail_over_mac=1"
NM_CONTROLLED=yes
```

После создания данных конфигурационных файлов неоьходимо перзапустить сеть:    
``systemctl restart NetworkManager``    

Тоже самое сделать на ``centralRouter``    

На некоторых версиях RHEL/CentOS перезапуск сетевого интерфейса не запустит bond-интерфейс, в этом случае рекомендуется перезапустить хост.    
После настройки агрегации портов, необходимо проверить работу bond-интерфейса, для этого, на хосте inetRouter ``(192.168.255.1)`` запустим ``ping до centralRouter (192.168.255.2)``:
``
[root@inetRouter ~]# ping 192.168.255.2
PING 192.168.255.2 (192.168.255.2) 56(84) bytes of data.
64 bytes from 192.168.255.2: icmp_seq=1 ttl=64 time=1.49 ms
64 bytes from 192.168.255.2: icmp_seq=2 ttl=64 time=1.00 ms
64 bytes from 192.168.255.2: icmp_seq=3 ttl=64 time=0.926 ms
64 bytes from 192.168.255.2: icmp_seq=4 ttl=64 time=0.912 ms
64 bytes from 192.168.255.2: icmp_seq=5 ttl=64 time=1.04 ms
64 bytes from 192.168.255.2: icmp_seq=6 ttl=64 time=0.889 ms
``
Не отменяя ping подключаемся к хосту centralRouter и выключаем там интерфейс ``eth1``:    
``[root@centralRouter ~]# ip link set down eth1``    
После данного действия ping не должен пропасть, так как трафик пойдёт по-другому порту.    



