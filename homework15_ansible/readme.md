Цель домашнего задания
----------------------
    Научиться работать с ansible
Описание/Пошаговая инструкция выполнения домашнего задания:
-----------------------------------------------------------

```
Подготовить стенд на Vagrant как минимум с одним сервером. На этом сервере используя Ansible необходимо развернуть nginx со следующими условиями:    
    
- необходимо исполþзовать модуль yum/apt    
- конфигурационные файлы должны быть взяты из шаблона jinja2 с переменными    
- после установки nginx должен быть в режиме enabled в systemd    
- должен быть использован notify для старта nginx после установки    
- сайт должен слушать на нестандартном порту - 8080, для этого использовать переменные в Ansible    
```

Описание:    

Playbook-а для установки NGINX.    
``nginx.yml`` и первым делом добавим в него установку пакета NGINX.    
Секция будет выглядеть так:    
```
- name: Install nginx package from epel repo
yum:
name: nginx
state: latest
tags:
- nginx-package Как видите добавлены tags
- packages
```

Обратите внимание - добавили Tags. Теперь можно вывести в консоль список тегов и выполнить, например, только установку NGINX. В нашем случае так, например, можно осуществлять его обновление.    

Выведем в консоль все теги:    
```
    ansible-playbook nginx.yml --list-tags    

playbook: nginx.yml    
play #1 (nginx): NGINX | Install and configure NGINX TAGS: []    
TASK TAGS: [epel-package, nginx-package, packages]    
```

Запустим только установку NGINX:    
```
    ansible-playbook nginx.yml -t nginx-package    
PLAY RECAP ******************************************************************    
nginx : ok=2 changed=0 unreachable=0 failed=0    
```

Далее добавим шаблон для конфига NGINX и модуль, который будет копировать этот шаблон на хост:    
```
- name: NGINX | Create NGINX config file from template    
template:    
src: templates/nginx.conf.j2    
dest: /tmp/nginx.conf    
tags:    
- nginx-configuration    
```

Сразу же пропишем в Playbook необходимую нам переменную. Нам нужно чтобы NGINX слушал на порту 8080:    
```
- name: NGINX | Install and configure NGINX    
hosts: nginx    
become: true    
vars:    
nginx_listen_port: 8080    
```
Сам шаблон будет выглядеть так:    
```    
events {    
worker_connections 1024;    
}    
     
http {    
server {    
listen {{ nginx_listen_port }} default_server;    
server_name default_server;    
root /usr/share/nginx/html;    
    
location / {    
}    
}    
}    
```

Теперь создадим ``handler`` и добавим ``notify`` к копированию шаблона. Теперь каждый раз когда конфиг будет изменяться - сервис перезагрузиться. Секция с ``handlers`` будет выглядеть следующим образом:    
```    
handlers:    
- name: restart nginx    
systemd:    
name: nginx    
state: restarted    
enabled: yes    
    
- name: reload nginx    
systemd:    
name: nginx    
state: reloaded    
    
Notify будут выглядеть так:    
- name: NGINX | Install NGINX package from EPEL Repo    
yum:    
name: nginx    
state: latest    
notify:    
- restart nginx    
tags:    
- nginx-package    
- packages    
    
- name: NGINX | Create NGINX config file from template    
template:    
src: templates/nginx.conf.j2    
dest: /etc/nginx/nginx.conf    
notify:    
- reload nginx    
tags:    
- nginx-configuration    
  
ansible-playbook nginx.yml    
PLAY [NGINX | Install and configure NGINX] **************************************    
    
TASK [Gathering Facts] ***********************************************************    
ok: [nginx]    
    
TASK [NGINX | Install EPEL Repo package from standart repo] *******************    
changed: [nginx]    
    
TASK [NGINX | Install NGINX package from EPEL Repo] **************************    
changed: [nginx]    
    
TASK [NGINX | Create NGINX config file from template] **************************    
changed: [nginx]    
    
RUNNING HANDLER [restart nginx] ***********************************************    
changed: [nginx]    
    
RUNNING HANDLER [reload nginx] ***********************************************    
changed: [nginx]    
    
PLAY RECAP *********************************************************************    
nginx : ok=6 changed=5 unreachable=0 failed=0    
```

Теперь можно перейти в браузере по адресу ``http://192.168.11.150:8080`` и убедиться, что сайт доступен.    