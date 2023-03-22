Цель домашнего задания:
-----------------------
    Научится самостоятельно устанавливать ZFS, настраивать пулы,изучить основные возможности ZFS.    

Описание домашнего задания:
---------------------------
```
1) Определить алгоритм с наилучшим сжатием
    Определить какие алгоритмы сжатия поддерживает zfs (gzip, zle, lzjb,lz4);
    Создать 4 файловых системы на каждой применить свой алгоритм сжатия;
    Для сжатия использовать либо текстовый файл, либо группу файлов:

2) Определить настройки пула
    С помощью команды zfs import собрать pool ZFS;
    Командами zfs определить настройки:
      - размер хранилища;
      - тип pool;
      - значение recordsize;
      - какое сжатие используется;
      - какая контрольная сумма используется.

3) Работа со снапшотами
    скопировать файл из удаленной директории.
    https://drive.google.com/file/d/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG/view?usp=sharing 
    восстановить файл локально. zfs receive
    найти зашифрованное сообщение в файле secret_message
```

### 1. Определить алгоритм с наилучшим сжатием.

    Создаём пул из двух дисков в режиме RAID 1    
        zpool create otus1 mirror /dev/sdb /dev/sdc
        zpool create otus2 mirror /dev/sdd /dev/sde
        zpool create otus3 mirror /dev/sdf /dev/sdg
        zpool create otus4 mirror /dev/sdh /dev/sdi
       
    Смотрим информацию о пулах:    
    
    zpool list
        NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
        otus1   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
        otus2   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
        otus3   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -
        otus4   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE 
    

    Добавим разные алгоритмы сжатия в каждую файловую систему:    
    
        zfs set compression=lzjb otus1
        zfs set compression=lz4 otus2
        zfs set compression=gzip-9 otus3
        zfs set compression=zle otus4
    

    Проверим, что все файловые системы имеют разные методы сжатия:    
    
    zfs get all | grep compression
        otus1 compression lzjb local
        otus2 compression lz4 local
        otus3 compression gzip-9 local
        otus4 compression zle local
    

    Сжатие файлов будет работать только с файлами, которые были добавлены после включение настройки сжатия.    
    Скачаем один и тот же текстовый файл во все пулы:    

        for i in {1..4}; do wget -P /otus$i https://gutenberg.org/cache/epub/2600/pg2600.converter.log; done
    И выведем ``ls -lh /otus*    
    
        /otus1:
        total 22005
        -rw-r--r--. 1 root root 40750827 Oct 2 08:07 pg2600.converter.log
        /otus2:
        total 17966
        -rw-r--r--. 1 root root 40750827 Oct 2 08:07 pg2600.converter.log
        /otus3:
        total 10945
        -rw-r--r--. 1 root root 40750827 Oct 2 08:07 pg2600.converter.log
        /otus4:
        total 39836
        -rw-r--r--. 1 root root 40750827 Oct 2 08:07 pg2600.converter.log
        
    Уже на этом этапе видно, что самый оптимальный метод сжатия у нас используется в пуле otus3.    

    Проверим, сколько места занимает один и тот же файл в разных пулах и проверим степень сжатия файлов:    
    
    zfs list
        NAME USED AVAIL REFER MOUNTPOINT
        otus1 21.6M 330M 21.5M /otus1
        otus2 17.7M 334M 17.6M /otus2
        otus3 10.8M 341M 10.7M /otus3
        otus4 39.0M 313M 38.9M /otus4

    zfs get all | grep compressratio | grep -v ref
        otus1 compressratio 1.80x -
        otus2 compressratio 2.21x -
        otus3 compressratio 3.63x -
        otus4 compressratio 1.00x -
        
    Таким образом, у нас получается, что алгоритм gzip-9 самый эффективный по сжатию.    


 ### 2.  Определить настройки пула

    Скачиваем архив в домашний каталог:    
    
        wget -O archive.tar.gz --no-check-certificate https://drive.google.com/u/0/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download    

    Разархивируем скачанный архив     
    
        tar -xzvf archive.tar.gz
            zpoolexport/
            zpoolexport/filea
            zpoolexport/fileb
            zpool get all otus
           
    Проверим, возможно ли импортировать данный каталог в пул:    
    
        zpool import -d zpoolexport/
        pool: otus
        id: 6554193320433390805
        state: ONLINE
        action: The pool can be imported using its name or numeric identifier.
        config:
                otus ONLINE
                mirror-0 ONLINE
                /root/zpoolexport/filea ONLINE
                /root/zpoolexport/fileb ONLINE
    

    Данный вывод показывает нам имя пула, тип raid и его состав.    

    Сделаем импорт данного пула к нам в ОС:    
    
        zpool import -d zpoolexport/ otus
        zpool status
        pool: otus
        state: ONLINE
        scan: none requested
        config:
                NAME STATE READ WRITE CKSUM
                otus ONLINE 0 0 0
                  mirror-0 ONLINE 0 0 0
                    /root/zpoolexport/filea ONLINE 0 0 0
                    /root/zpoolexport/fileb ONLINE 0 0 0
    

    Далее нам нужно определить настройки    
    Запрос сразу всех параметров пула:    
    
        zpool get all otus
            NAME  PROPERTY                       VALUE                          SOURCE
            otus  size                           480M                           -
            otus  capacity                       0%                             -
            otus  altroot                        -                              default
            otus  health                         ONLINE                         -
            otus  guid                           6554193320433390805            -
            otus  version                        -                              default
            otus  bootfs                         -                              default
            otus  delegation                     on                             default
            otus  autoreplace                    off                            default
            otus  cachefile                      -                              default
            otus  failmode                       wait                           default
            otus  listsnapshots                  off                            default
            otus  autoexpand                     off                            default
            otus  dedupditto                     0                              default
            otus  dedupratio                     1.00x                          -
            otus  free                           478M                           -
            otus  allocated                      2.09M                          -
            otus  readonly                       off                            -
            otus  ashift                         0                              default
            otus  comment                        -                              default
            otus  expandsize                     -                              -
            otus  freeing                        0                              -
            otus  fragmentation                  0%                             -
            otus  leaked                         0                              -
            otus  multihost                      off                            default
            otus  checkpoint                     -                              -
            otus  load_guid                      239450987921007998             -
            otus  autotrim                       off                            default
            otus  feature@async_destroy          enabled                        local
            otus  feature@empty_bpobj            active                         local
            otus  feature@lz4_compress           active                         local
            otus  feature@multi_vdev_crash_dump  enabled                        local
            otus  feature@spacemap_histogram     active                         local
            otus  feature@enabled_txg            active                         local
            otus  feature@hole_birth             active                         local
            otus  feature@extensible_dataset     active                         local
            otus  feature@embedded_data          active                         local
            otus  feature@bookmarks              enabled                        local
            otus  feature@filesystem_limits      enabled                        local
            otus  feature@large_blocks           enabled                        local
            otus  feature@large_dnode            enabled                        local
            otus  feature@sha512                 enabled                        local
            otus  feature@skein                  enabled                        local
            otus  feature@edonr                  enabled                        local
            otus  feature@userobj_accounting     active                         local
            otus  feature@encryption             enabled                        local
            otus  feature@project_quota          active                         local
            otus  feature@device_removal         enabled                        local
            otus  feature@obsolete_counts        enabled                        local
            otus  feature@zpool_checkpoint       enabled                        local
            otus  feature@spacemap_v2            active                         local
            otus  feature@allocation_classes     enabled                        local
            otus  feature@resilver_defer         enabled                        local
            otus  feature@bookmark_v2            enabled                        local
    

    C помощью команды grep можно уточнить конкретный параметр, например:    
    
        zfs get available otus
            NAME  PROPERTY   VALUE  SOURCE
            otus  available  347M   -
    

    По типу FS мы можем понять, что позволяет выполнять чтение и запись    

    Значение recordsize: zfs get recordsize otus    
        zfs get recordsize otus
            NAME PROPERTY VALUE SOURCE
            otus recordsize 128K local

    Тип сжатия (или параметр отключения): zfs get compression otus
        zfs get compression otus
            NAME PROPERTY VALUE SOURCE
            otus compression zle local

    Тип контрольной суммы: zfs get checksum otus
        zfs get checksum otus
            NAME PROPERTY VALUE SOURCE
            otus checksum sha256 local


### 3. Работа со снапшотом

    Скачаем файл, указанный в задании:    
    
        wget -O otus_task2.file --no-check-certificate 
            https://drive.google.com/u/0/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download
            
    Восстановим файловую систему из снапшота:     

        zfs receive otus/test@today < otus_task2.file
    Далее, ищем в каталоге /otus/test файл с именем “secret_message”:    
    
        find /otus/test -name "secret_message"
        /otus/test/task1/file_mess/secret_message
    

    Смотрим содержимое найденного файла:    
    
    cat /otus/test/task1/file_mess/secret_message
        https://github.com/sindresorhus/awesome   
    

    Тут мы видим ссылку на GitHub, можем скопировать её в адресную строку и посмотреть репозиторий.    


Для конфигурации сервера установки и настройки ZFS.    

vim zfs_script.sh 

    #!/bin/env bash
    yum update -y
    yum install -y yum-utils
    #install zfs repo
    yum install -y http://download.zfsonlinux.org/epel/zfs-release.el7_4.noarch.rpm
    #install DKMS style packages for correct work ZFS
    yum install -y epel-release kernel-devel zfs
    #change ZFS repo
    yum-config-manager --disable zfs
    yum-config-manager --enable zfs-kmod
    yum install -y zfs
    #Add kernel module zfs
    modprobe zfs
    #install wget
    yum install -y wget


И прописать строчку в ``Vagrantfile`` 

cat Vagrantfile | grep box.vm.provision
box.vm.provision "shell", path: "zfs_script.sh"    
