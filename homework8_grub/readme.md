Цель домашнего задания
Научиться входить в систему без пароля несколькими способами, добавлять модуль в initrd

Описание домашнего задания
1. Попасть в систему без пароля несколькими способами.
2. Установить систему с LVM, после чего переименовать VG.
3. Добавить модуль в initrd.


1. Попасть в систему без пароля несколькими способами.

Для получения доступа необходимо открыть GUI VirtualBox, запустить виртуальную машину и при выборе ядра для загрузки нажать e - в данном контексте edit. Попадаем в окно где мы можем изменить параметры загрузки:

Способ 1. init=/bin/sh 

В конце строки начинаящейся с linux16 добавляем init=/bin/sh и нажимаем сtrl-x для загрузки в систему.
В целом на этом все, вы попали в систему. Но есть один нюанс. Рутовая файловая система при этом монтируется в режиме Read-Only.
grep '\W/\W' /proc/mounts  - просмотр смонтированных фС
    rootfs /rootfs rw 0 0
    /dev/maper/cl-root / xfs ro,relatime,attr2,inode64,noquota 0 0

Монтируем ФС для чтения записи
    mount -o remount, rw /  
     /dev/maper/cl-root / xfs rw,relatime,attr2,inode64,noquota 0 0

Загружаем политику для SELINUX 
    /sbin/load_policy -i

Проверяем загрузку метки для файла /etc/shadow
    ls -Z /etc/shadow
    ----------. root root system_u:object_r:unlabeled_t:s0 /etc/shadow

Задаём новый пароль
    passwd root
    Changing password for user root.
    New password:
    Retype new password:
    passwd: all authentication tokens updated successfully.

 Перегружаем систему 
    exec /sbin/init   

Способ 2. rd.break

В конце строки начинающейся с linux16 добавляем rd.break и нажимаем сtrl-x для загрузки в систему
Попадаем в emergency mode. Наша корневая файловая система смонтирована (опять же в режиме Read-Only, но мы не в ней. Далее будет пример как попасть в нее и поменять пароль администратора:

    Монтируем ФС в режиме чтения записи
    mount -o remount,rw /sysroot
    chroot /sysroot
    passwd root
    touch /.autorelabel

Способ 3. rw init=/sysroot/bin/sh

В строке начинающейся с linux16 заменяем ro на rw init=/sysroot/bin/sh и нажимаем сtrl-x для загрузки в систему. В целом то же самое что и в прошлом примере, но файловая система сразу смонтирована в режим Read-Write. 
    grep '\W/\W' /proc/mounts
    rootfs / rootfs rw 0 0
И можно менять пароль.

2. Установить систему с LVM, после чего переименовать VG.

Первым делом посмотрим текущее состояние систему:
    vgs
        VG #PV #LV #SN Attr VSize VFree
        VolGroup00 1 2 0 wz--n- <19.00g 0
Нас интересует вторая строка с именем Volume Group
Переименовываем 
    vgrename VolGroup00 OtusRoot
    Volume group "VolGroup00" successfully renamed to "OtusRoot"

 Далее правим /etc/fstab, /etc/default/grub, /boot/grub2/grub.cfg.
Везде заменяем старое название на новое. По ссылкам можно увидеть примеры получившихся файлов.
Пересоздаем initrd image, чтобы он знал новое название Volume Group
    mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)
    *** Creating image file done ***
    *** Creating initramfs image file '/boot/initramfs-3.10.0-514.el7.x86_64.img' done ***

После чего можем перезагружаться и если все сделано правильно успешно грузимся с новым именем Volume Group и проверяем:
    vgs
         VG       #PV #LV #SN Attr   VSize  VFree
        OtusRoot   1   2   0 wz--n- 19,00g    0 
    
3. Добавить модуль в initrd.
    
Скрипты модулей хранятся в каталоге /usr/lib/dracut/modules.d/. Для того чтобы добавить свой модуль создаем там папку с именем 01test:
    mkdir /usr/lib/dracut/modules.d/01test
        module-setup.sh - который устанавливает модуль и вызывает скрипт test.sh
        test.sh - собственно сам вызываемый скрипт, в нём у нас рисуется пингвинчик

Скрипты

module-setup.sh

    #!/bin/bash
    check() {
        return 0
    }
    depends() {
        return 0
    }
    install() {
        inst_hook cleanup 00 "${moddir}/test.sh"
    }

test.sh
    #!/bin/bash
    exec 0<>/dev/console 1<>/dev/console 2<>/dev/console
    cat <<'msgend'
    Hello! You are in dracut module!
    ___________________
    < I'm dracut module >
    -------------------
    \
        \
         .--.
        |o_o |
        |:_/ |
        //   \ \
        (|     | )
        /'\_   _/`\
        \___)=(___/
    msgend
    sleep 10
    echo " continuing...."

Пересобираем образ initrd
    mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)
или
    dracut -f -v
Можно проверить/посмотреть какие модули загружены в образ:
lsinitrd -m /boot/initramfs-$(uname -r).img | grep test
    test

После чего можно пойти двумя путями для проверки:
    Перезагрузиться и руками выключить опции rghb и quiet и увидеть вывод
    Либо отредактировать grub.cfg убрав эти опции
    В итоге при загрузке будет пауза на 10 секунд и вы увидите пингвина в выводе терминала
