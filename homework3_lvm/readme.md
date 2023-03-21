Цель домашнего задания
----------------------
``    Научиться создавать и работать с LVM ``
Описание домашнего задания:
---------------------------
```
На имеющемся образе centos/7 - v. 1804.2
1) Уменьшиить том под / до 8G
2) Выделить том под /home
3) Выделить том под /var - сделать в mirror
4) /home - сделать том для снапшотов
5) Прописать монтирование в fstab.
Работа со снапшотами:
- сгенерить файлы в /home/
- снять снапшот
- удалить часть файлов
- восстановиться со снапшота
```
### 1. Уменьшить том под / до 8G 
Эту часть можно выполнить разными способами, в данном примере мы будем уменьшать / до 8G без использования LiveCD.      
Перед началом работы поставьте пакет xfsdump - он будет необходим для снятия копии / тома.    
Подготовим временный том для / раздела:    
```
pvcreate /dev/sdb
 Physical volume "/dev/sdb" successfully created.

vgcreate vg_root /dev/sdb
 Volume group "vg_root" successfully created

lvcreate -n lv_root -l +100%FREE /dev/vg_root
 Logical volume "lv_root" created.
```

Создадим на нем файловую систему и смонтируем его, чтобы перенести туда данные:    
```
mkfs.xfs /dev/vg_root/lv_root
mount /dev/vg_root/lv_root /mnt
```
Этой командой скопируем все данные с ``/ раздела в /mnt:``
```
xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
xfsrestore: Restore Status: SUCCESS
```
Тут выхлоп большой, но в итоге вы должны увидеть ``SUCCESS``. Проверить что скопировалось можно командой ``ls /mnt``    
Затем переконфигурируем grub для того, чтобы при старте перейти в новый /    
Сымитируем текущий root -> сделаем в него chroot и обновим grub:    
```
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
chroot /mnt/
grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-862.2.3.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img
done
```

Обновим образ ``initrd``.    
```
cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
*** Creating image file ***
*** Creating image file done ***
*** Creating initramfs image file '/boot/initramfs-3.10.0-862.2.3.el7.x86_64.img' done ***
```
Ну и для того, чтобы при загрузке был смонтирован нужны root нужно в файле    

``/boot/grub2/grub.cfg заменить rd.lvm.lv=VolGroup00/LogVol00 на rd.lvm.lv=vg_root/lv_root``

Теперь нам нужно изменить размер старой VG и вернуть на него рут. Для этого удаляем старый ``LV размеров в 40G и создаем новый на 8G``:    
```
lvremove /dev/VolGroup00/LogVol00
Do you really want to remove active logical volume VolGroup00/LogVol00? [y/n]: y
Logical volume "LogVol00" successfully removed
lvcreate -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
WARNING: xfs signature detected on /dev/VolGroup00/LogVol00 at offset 0. Wipe it? [y/n]: y
Wiping xfs signature on /dev/VolGroup00/LogVol00.
Logical volume "LogVol00" created.
```
Проделываем на нем те же операции, что и в первый раз:    
```
mkfs.xfs /dev/VolGroup00/LogVol00
mount /dev/VolGroup00/LogVol00 /mnt
xfsdump -J - /dev/vg_root/lv_root | xfsrestore -J - /mnt
xfsdump: Dump Status: SUCCESS
xfsrestore: restore complete: 37 seconds elapsed
xfsrestore: Restore Status: SUCCESS
```
Так же как в первый раз переконфигурируем grub, за исключением правки ``/etc/grub2/grub.cfg``    
```
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
chroot /mnt/
grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-862.2.3.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img
done
cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g;
s/.img//g"` --force; done
*** Creating image file ***
*** Creating image file done ***
*** Creating initramfs image file '/boot/initramfs-3.10.0-862.2.3.el7.x86_64.img' done ***
```

### 2. Выделить том под /var в зеркало 

На свободных дисках создаем зеркало:    
```
pvcreate /dev/sdc /dev/sdd
 Physical volume "/dev/sdc" successfully created.
 Physical volume "/dev/sdd" successfully created.

vgcreate vg_var /dev/sdc /dev/sdd
 Volume group "vg_var" successfully created

lvcreate -L 950M -m1 -n lv_var vg_var
 Rounding up size to full physical extent 952.00 MiB
 Logical volume "lv_var" created.
``` 
Создаем на нем ФС и перемещаем туда ``/var``:    
```
mkfs.ext4 /dev/vg_var/lv_var
Writing superblocks and filesystem accounting information: done
mount /dev/vg_var/lv_var /mnt
cp -aR /var/* /mnt/ # rsync -avHPSAX /var/ /mnt/
```

На всякий случай сохраняем содержимое старого var (или же можно его просто удалить):    

``mkdir /tmp/oldvar && mv /var/* /tmp/oldvar``

Ну и монтируем новый var в каталог /var:    
```
umount /mnt
mount /dev/vg_var/lv_var /var
```
Правим ``fstab`` для автоматического монтирования ``/var``:    

``echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab``
После чего можно успешно перезагружаться в новый (уменьшенный root) и удалять временный Volume Group:    
```
lvremove /dev/vg_root/lv_root
Do you really want to remove active logical volume vg_root/lv_root? [y/n]: y
 Logical volume "lv_root" successfully removed

vgremove /dev/vg_root
 Volume group "vg_root" successfully removed

pvremove /dev/sdb
 Labels on physical volume "/dev/sdb" successfully wiped.
```
### 3. Выделить том под /home
Выделяем том под /home по тому же принципу что делали для /var:    
```
lvcreate -n LogVol_Home -L 2G /dev/VolGroup00
 Logical volume "LogVol_Home" created.

mkfs.xfs /dev/VolGroup00/LogVol_Home
mount /dev/VolGroup00/LogVol_Home /mnt/
cp -aR /home/* /mnt/
rm -rf /home/*
umount /mnt
mount /dev/VolGroup00/LogVol_Home /home/
Правим fstab для автоматического монтирования /home
echo "`blkid | grep Home | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab 

/home - сделать том для снапшотов

Сгенерируем файлы в /home/:
touch /home/file{1..20}

Снять снапшот:

lvcreate -L 100MB -s -n home_snap /dev/VolGroup00/LogVol_Home

Удалить часть файлов:
rm -f /home/file{11..20}

Процесс восстановления со снапшота:
umount /home

lvconvert --merge /dev/VolGroup00/home_snap
mount /home
```