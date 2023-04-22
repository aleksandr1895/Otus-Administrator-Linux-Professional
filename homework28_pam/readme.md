Цель домашнего задания
----------------------
Научиться создавать пользователей и добавлять им ограничения    

Описание домашнего задания
--------------------------
1) Запретить всем пользователям, кроме группы admin, логин в выходные (суббота и воскресенье), без учета праздников    

Создадим Vagrantfile, в котором будут указаны параметры наших ВМ:    
```
# Описание параметров ВМ
MACHINES = {
  # Имя DV "pam"
  :"pam" => {
              # VM box
              :box_name => "centos/stream8",
              #box_version
              :box_version => "20210210.0",
              # Количество ядер CPU
              :cpus => 2,
              # Указываем количество ОЗУ (В Мегабайтах)
              :memory => 1024,
              # Указываем IP-адрес для ВМ
              :ip => "192.168.57.10",
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    # Отключаем сетевую папку
    config.vm.synced_folder ".", "/vagrant", disabled: true
    # Добавляем сетевой интерфейс
    config.vm.network "private_network", ip: boxconfig[:ip]
    # Применяем параметры, указанные выше
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.box_version = boxconfig[:box_version]
      box.vm.host_name = boxname.to_s

      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
      box.vm.provision "shell", inline: <<-SHELL
          #Разрешаем подключение пользователей по SSH с использованием пароля
          sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
          #Перезапуск службы SSHD
          systemctl restart sshd.service
  	  SHELL
    end
  end
end
```

После создания Vagrantfile запустим нашу ВМ командой vagrant up. Будет создана одна виртуальная машина.    

### 1) Запретить всем пользователям, кроме группы admin, логин в выходные (суббота и воскресенье), без учета праздников  

Настройка запрета для всех пользователей (кроме группы Admin) логина в выходные дни (Праздники не учитываются)    
```
1. Подключаемся к нашей созданной ВМ: vagrant ssh
2. Переходим в root-пользователя: sudo -i
3. Создаём пользователя otusadm и otus: sudo useradd otusadm && sudo useradd otus
4. Создаём пользователям пароли: echo "Otus2022!" | sudo passwd --stdin otusadm && echo "Otus2022!" | sudo passwd --stdin otus
Для примера мы указываем одинаковые пароли для пользователя otus и otusadm
5. Создаём группу admin: sudo groupadd -f admin
6. Добавляем пользователей vagrant,root и otusadm в группу admin:

    sudo usermod otusadm -a -G admin
    sudo usermod root -a -G admin
    sudo usermod vagrant -a -G admin
```

Обратите внимание, что мы просто добавили пользователя otusadm в группу admin. Это не делает пользователя otusadm администратором.    

После создания пользователей, нужно проверить, что они могут подключаться по SSH к нашей ВМ.    
Для этого пытаемся подключиться с хостовой машины:    
ssh otus@192.168.57.10    
Далее вводим наш созданный пароль.    

```
ssh otus@192.168.57.10
The authenticity of host '192.168.57.10 (192.168.57.10)' can't be established.
ECDSA key fingerprint is SHA256:QRQNZFlIsBkiJN/US58G2/eQsb/BYF3OX6moTCeNKF8.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.57.10' (ECDSA) to the list of known hosts.
otus@192.168.57.10's password: 
Permission denied, please try again.
otus@192.168.57.10's password: 
Last failed login: Thu Mar 30 06:24:57 UTC 2023 from 192.168.57.1 on ssh:notty
There was 1 failed login attempt since the last successful login.
[otus@pam ~]$ 
[otus@pam ~]$ whoami
otus
```

```
ssh otusadm@192.168.57.10
The authenticity of host '192.168.57.10 (192.168.57.10)' can't be established.
ECDSA key fingerprint is SHA256:QRQNZFlIsBkiJN/US58G2/eQsb/BYF3OX6moTCeNKF8.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.57.10' (ECDSA) to the list of known hosts.
otusadm@192.168.57.10's password: 
Last failed login: Thu Mar 30 06:30:31 UTC 2023 from 192.168.57.1 on ssh:notty
There were 5 failed login attempts since the last successful login.
[otusadm@pam ~]$ whoami
```
Если всё настроено правильно, на этом моменте мы сможет подключиться по SSH под пользователем otus и otusadm    

Проверим, что пользователи root, vagrant и otusadm есть в группе admin:    
```
cat /etc/group | grep admin
printadmin:x:994:
admin:x:1003:otusadm,root,vagrant
```

Создадим файл-скрипт ``/usr/local/bin/login.sh``

```
vi /usr/local/bin/login.sh
#!/bin/bash
#Первое условие: если день недели суббота или воскресенье
if [ $(date +%a) = "Sat" ] || [ $(date +%a) = "Sun" ]; then
 #Второе условие: входит ли пользователь в группу admin
 if getent group admin | grep -qw "$PAM_USER"; then
        #Если пользователь входит в группу admin, то он может подключиться
        exit 0
      else
        #Иначе ошибка (не сможет подключиться)
        exit 1
    fi
  #Если день не выходной, то подключиться может любой пользователь
  else
    exit 0
fi
```
В скрипте подписаны все условия. Скрипт работает по принципу:    
Если сегодня суббота или воскресенье, то нужно проверить, входит ли пользователь в группу admin, если не входит — то подключение запрещено. При любых других вариантах подключение разрешено.    

Добавим права на исполнение файла: ``chmod +x /usr/local/bin/login.sh``

Укажем в файле /etc/pam.d/sshd модуль pam_exec и наш скрипт:    

```
vi /etc/pam.d/sshd    
#%PAM-1.0
auth       substack     password-auth
auth       include      postlogin
account    required     pam_exec.so /usr/local/bin/login.sh
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    optional     pam_motd.so
session    include      password-auth
session    include      postlogin
```

На этом настройка завершена, нужно только проверить, что скрипт отрабатывает корректно.    


