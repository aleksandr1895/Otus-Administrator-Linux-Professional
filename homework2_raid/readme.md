Цель домашнего задания
----------------------
    Научиться создавать программные raid-массивы и работать с утилитой mdadm
Описание домашнего задания:
---------------------------
```
    добавить в Vagrantfile еще дисков;
    сломать/починить raid;
    собрать R0/R5/R10 на выбор;
    прописать собранный рейд в конф, чтобы рейд собирался при загрузке;
    создать GPT раздел и 5 партиций.
```
### 1. Создание Raid массива 
```    
С помощью утилиты fdisk проверим подключенные дииски и создадим таблицу разделов.    
Занулим на всякий случай суперблоки:    
mdadm --zero-superblock --force /dev/sd{b,c,d,e,f}
И можно создавать рейд следующей командой:
mdadm --create --verbose /dev/md0 -l 6 -n 5 /dev/sd{b,c,d,e,f}
Мы выбрали RAID 6. Опция -l какого уровня RAID создавать.
Опция -n указывает на кол-во устройств в RAID.
```

Проверим что RAID собрался нормально:    
```    
cat /proc/mdstat    
Personalities : [raid6] [raid5] [raid4] 
md0 : active raid6 sdf[4] sde[3] sdd[2] sdc[1] sdb[0]
      761856 blocks super 1.2 level 6, 512k chunk, algorithm 2 [5/5] [UUUUU]
```
```
mdadm -D /dev/md0
 Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8       32        1      active sync   /dev/sdc
       2       8       48        2      active sync   /dev/sdd
       3       8       64        3      active sync   /dev/sde
       4       8       80        4      active sync   /dev/sdf
```

### 2. Создание конфигурационного файла mdadm.conf

Для того, чтобы быть уверенным что ОС запомнила какой RAID массив требуется создать и какие компоненты в него входят создадим файл  mdadm.conf    

Сначала убедимся, что информация верна: ``mdadm --detail --scan --verbose``    
```
ARRAY /dev/md0 level=raid6 num-devices=5 metadata=1.2 name=otuslinux:0 UUID=8b45d76c:6b992401:4d8191d1:2c8552eb
   devices=/dev/sdb,/dev/sdc,/dev/sdd,/dev/sde,/dev/sdf
```
А затем в две команды создадим файл ``mdadm.conf``
```
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
```
### 3. Сломать/починить RAID
```
mdadm /dev/md0 --fail /dev/sde 
mdadm: set /dev/sde faulty in /dev/md0

Удалим “сломанный” диск из массива:    
mdadm /dev/md0 --remove /dev/sde
mdadm: hot removed /dev/sde from /dev/md0
```
Представим, что мы вставили новый диск в сервер и теперь нам нужно добавить его в RAID. Делается это так:    
```
mdadm /dev/md0 --add /dev/sde
mdadm: added /dev/sde
```
Диск должен перейти в стадию ``rebuilding``.    

### 4. Создать GPT раздел, пять партиций и смонтировать их на диск

Создаем раздел GPT на RAID    
``parted -s /dev/md0 mklabel gpt``

Создаем партиции    
```
parted /dev/md0 mkpart primary ext4 0% 20%
parted /dev/md0 mkpart primary ext4 20% 40%
parted /dev/md0 mkpart primary ext4 40% 60%
parted /dev/md0 mkpart primary ext4 60% 80%
parted /dev/md0 mkpart primary ext4 80% 100%
```
Далее можно создать на этих партициях ФС    
``for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done``

И смонтировать их по каталогам    
```
$ mkdir -p /raid/part{1,2,3,4,5}
$ for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
```