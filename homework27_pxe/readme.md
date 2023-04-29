Цель домашнего задания
----------------------
Отработать навыки установки и настройки DHCP, TFTP, PXE загрузчика и автоматической загрузки

Описание домашнего задания
--------------------------
1. Следуя шагам из документа https://docs.centos.org/en-US/8-docs/advanced-install/assembly_preparing-for-a-network-install  установить и настроить загрузку по сети для дистрибутива CentOS 8. В качестве шаблона воспользуйтесь репозиторием https://github.com/nixuser/virtlab/tree/main/centos_pxe   

2. Поменять установку из репозитория NFS на установку из репозитория HTTP.    

3. Настроить автоматическую установку для созданного kickstart файла(*) Файл загружается по HTTP.    


Запускаем Vagrant, vagrant запустится с ошибкой, так как на Pxeclient настроена загрузка по сети.    

``**Настройка Web-сервера**``

Для того, чтобы отдавать файлы по HTTP нам потребуется настроенный веб-сервер.    

``Процесс настройки вручную:`` 

0. Так как у CentOS 8 закончилась поддержка, для установки пакетов нам потребуется поменять репозиторий. Сделать это можно с помощью следующих команд:    
```
  sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-*
  sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Linux-*
```  
1. Устанавливаем Web-сервер Apache: ``yum install httpd``    
2. Далее скачиваем образ CentOS 8.4.2150:    
wget https://mirror.sale-dedic.com/centos/8.4.2105/isos/x86_64/CentOS-8.4.2105-x86_64-dvd1.iso    
Размер образа больше 9ГБ, скачивание может занять продолжительное время.    
3. Монтируем данный образ:    
mount -t iso9660 CentOS-8.4.2105-x86_64-dvd1.iso /mnt -o loop,ro    
4. Создаём каталог /iso и копируем в него содержимое данного каталога:    
mkdir /iso    
cp -r /mnt/* /iso    
5. Ставим права 755 на каталог /iso: chmod -R 755 /iso    
6. Настраиваем доступ по HTTP для файлов из каталога /iso:    
Создаем конфигурационный файл: vi /etc/httpd/conf.d/pxeboot.conf    

Добавляем следующее содержимое в файл:    
``Alias /centos8 /iso``    
#Указываем адрес директории /iso    
```
<Directory /iso>
    Options Indexes FollowSymLinks
    #Разрешаем подключения со всех ip-адресов
    Require all granted
```    
Перезапускаем веб-сервер: ``systemctl restart httpd``    
Добавляем его в автозагрузку: ``systemctl enable httpd``    
7. Проверяем, что веб-сервер работает и каталог /iso доступен по сети:    

``**Настройка TFTP-сервера**``

TFTP-сервер потребуется для отправки первичных файлов загрузки ``(vmlinuz, initrd.img и т. д.)``    

1. Устанавливаем tftp-сервер: ``yum install tftp-server``    
2. Запускаем службу: ``systemctl start tftp.service``    
3. Проверяем, в каком каталоге будут храниться файлы, которые будет отдавать     
```
TFTP-сервер:
[root@pxeserver ~]# systemctl status tftp.service
● tftp.service - Tftp Server
   Loaded: loaded (/usr/lib/systemd/system/tftp.service; indirect; vendor preset: disabled)
   Active: active (running) since Sun 2022-02-06 20:53:28 UTC; 4s ago
     Docs: man:in.tftpd
 Main PID: 7732 (in.tftpd)
    Tasks: 1 (limit: 4953)
   Memory: 248.0K
   CGroup: /system.slice/tftp.service
           └─7732 /usr/sbin/in.tftpd -s /var/lib/tftpboot

Feb 06 20:53:28 pxeserver systemd[1]: Started Tftp Server.
```
В статусе видим, что рабочий каталог ``/var/lib/tftpboot``    
4. Созаём каталог, в котором будем хранить наше меню загрузки:    
``mkdir /var/lib/tftpboot/pxelinux.cfg``    
5. Создаём меню-файл: ``vi /var/lib/tftpboot/pxelinux.cfg/default``    
```
default menu.c32
prompt 0
#Время счётчика с обратным отсчётом (установлено 15 секунд)    
timeout 150    
#Параметр использования локального времени    
ONTIME local    
#Имя «шапки» нашего меню    
menu title OTUS PXE Boot Menu    
       #Описание первой строки
       label 1
       #Имя, отображаемое в первой строке
       menu label ^ Graph install CentOS 8.4
       #Адрес ядра, расположенного на TFTP-сервере
       kernel /vmlinuz
       #Адрес файла initrd, расположенного на TFTP-сервере
       initrd /initrd.img
       #Получаем адрес по DHCP и указываем адрес веб-сервера
       append ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8
       label 2
       menu label ^ Text install CentOS 8.4
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8 text
       label 3
       menu label ^ rescue installed system
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8 rescue

Label 1-3 различаются только дополнительными параметрами:
label 1 — установка вручную в графическом режиме
label 2 — установка вручную в текстовом режиме
label 3 — восстановление системы
```
6. Распакуем файл ``syslinux-tftpboot-6.04-5.el8.noarch.rpm:``    
``rpm2cpio /iso/BaseOS/Packages/syslinux-tftpboot-6.04-5.el8.noarch.rpm | cpio -dimv``    

7. После распаковки в каталоге пользователя root будет создан каталог tftpboot из которого потребуется скопировать следующие файлы:    
```
- pxelinux.0    
- ldlinux.c32    
- libmenu.c32    
- libutil.c32    
- menu.c32    
- vesamenu.c32    
cd tftpboot    
cp pxelinux.0 ldlinux.c32 libmenu.c32 libutil.c32 menu.c32 vesamenu.c32 /var/lib/tftpboot/
```
8. Также в каталог ``/var/lib/tftpboot/`` нам потребуется скопировать файлы ``initrd.img и vmlinuz``, которые располагаются в каталоге ``/iso/images/pxeboot/:``
``cp /iso/images/pxeboot/{initrd.img,vmlinuz} /var/lib/tftpboot/``    

9. Далее перезапускаем TFTP-сервер и добавляем его в автозагрузку:    
```
systemctl restart tftp.service 
systemctl enable tftp.service
```

``**Настройка DHCP-сервера**``
```
1. Устанавливаем DHCP-сервер: yum install dhcp-server
2. Правим конфигурационный файл: vi /etc/dhcp/dhcpd.conf
option space pxelinux;
option pxelinux.magic code 208 = string;
option pxelinux.configfile code 209 = text;
option pxelinux.pathprefix code 210 = text;
option pxelinux.reboottime code 211 = unsigned integer 32;
option architecture-type code 93 = unsigned integer 16;

#Указываем сеть и маску подсети, в которой будет работать DHCP-сервер
subnet 10.0.0.0 netmask 255.255.255.0 {
        #Указываем шлюз по умолчанию, если потребуется
        #option routers 10.0.0.1;
        #Указываем диапазон адресов
        range 10.0.0.100 10.0.0.120;

        class "pxeclients" {
          match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
          #Указываем адрес TFTP-сервера
          next-server 10.0.0.20;
          #Указываем имя файла, который надо запустить с TFTP-сервера
          filename "pxelinux.0";
        }
```

На данном этапе мы закончили настройку PXE-сервера для ручной установки сервера. Давайте попробуем запустить процесс установки вручную, для удобства воспользуемся установкой через графический интерфейс:    

Запускаем Виртуальную машину , выбираем графическую установку.    
После этого, будут скачаны необходимые файлы с веб-сервера.    
Как только появится окно установки, нам нужно будет поочереди пройти по всем компонентам и указать с какими параметрами мы хотим установить ОС:    

После установки всех, нужных нам параметров нажимаем Begin installation    
После этого начнётся установка системы, после установки всех компонентов нужно будет перезагрузить ВМ и запуститься с диска.     

Если нам не хочется вручную настраивать каждую установку, то мы можем автоматизировать этот процесс с помощью файла автоматиеской установки (kickstart file)


``**Настройка автоматической установки с помощью Kickstart-файла**``    

1. Создаем kickstart-файл и кладём его в каталог к веб-серверу:    
```
vi /iso/ks.cfg    

#version=RHEL8
#Использование в установке только диска /dev/sda
ignoredisk --only-use=sda
autopart --type=lvm
#Очистка информации о партициях
clearpart --all --initlabel --drives=sda
#Использование графической установки
graphical
#Установка английской раскладки клавиатуры
keyboard --vckeymap=us --xlayouts='us'
#Установка языка системы
lang en_US.UTF-8
#Добавление репозитория
url —url=http://10.0.0.20/centos8/BaseOS/
#Сетевые настройки
network  --bootproto=dhcp --device=enp0s3 --ipv6=auto --activate
network  --bootproto=dhcp --device=enp0s8 --onboot=off --ipv6=auto --activate
network  --hostname=otus-pxe-client
#Устанвка пароля root-пользователю (Указан SHA-512 hash пароля 123)
rootpw --iscrypted $6$sJgo6Hg5zXBwkkI8$btrEoWAb5FxKhajagWR49XM4EAOfO/Dr5bMrLOkGe3KkMYdsh7T3MU5mYwY2TIMJpVKckAwnZFs2ltUJ1abOZ.
firstboot --enable
#Не настраиваем X Window System
skipx
#Настраиваем системные службы
services --enabled="chronyd"
#Указываем часовой пояс
timezone Europe/Moscow --isUtc
user --groups=wheel --name=val --password=$6$ihX1bMEoO3TxaCiL$OBDSCuY.EpqPmkFmMPVvI3JZlCVRfC4Nw6oUoPG0RGuq2g5BjQBKNboPjM44.0lJGBc7OdWlL17B3qzgHX2v// --iscrypted --gecos="val"
%packages
@^minimal-environment
kexec-tools
%end
%addon com_redhat_kdump --enable --reserve-mb='auto'
%end
%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
```

2. Добавляем параметр в меню загрузки:    
```
vi /var/lib/tftpboot/pxelinux.cfg/default 
default menu.c32
prompt 0
timeout 150
ONTIME local
menu title OTUS PXE Boot Menu
       label 1
       menu label ^ Graph install CentOS 8.4
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8
       label 2
       menu label ^ Text install CentOS 8.4
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8 text
       label 3
       menu label ^ rescue installed system
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8 rescue
       label 4
       menu label ^ Auto-install CentOS 8.4
       #Загрузка данного варианта по умолчанию
       menu default
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.ks=http://10.0.0.20/centos8/ks.cfg inst.repo=http://10.0.0.20/centos8/
```

В append появляется дополнительный параметр inst.ks, в котором указан адрес kickstart-файла.    
Если вы хотите сгенерировать хэш другого пароля, то сделать это можно с помощью команды: 
``python3 -c 'import crypt,getpass; print(crypt.crypt(getpass.getpass(), crypt.mksalt(crypt.METHOD_SHA512)))'``
