#! /bin/bash

sudo su
#Устанавливаем недостающие пакеты
yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils lynx gcc
#Скачиваем и устанвавливаем nginx
wget http://nginx.org/packages/mainline/centos/7/SRPMS/nginx-1.23.3-1.el7.ngx.src.rpm
rpm -ivh nginx-1.23.3-1.el7.ngx.src.rpm
#Скачиваем и разархивируем openssl
wget --no-check-certificate https://www.openssl.org/source/old/1.1.1/openssl-1.1.1q.tar.gz
tar -xvf openssl-1.1.1q.tar.gz --directory /usr/lib
# Установка зависимостей и подключение опций
yum-builddep rpmbuild/SPECS/nginx.spec
sed -i "s|--with-stream_ssl_preread_module|--with-stream_ssl_preread_module --with-openssl=/usr/lib/openssl-1.1.1q --with-openssl-opt=enable-tls1_3|g" /root/rpmbuild/SPECS/nginx.spec
#Компиляция
rpmbuild -ba /root/rpmbuild/SPECS/nginx.spec
#Установка и запуск с локального репозитория

yum localinstall -y /root/rpmbuild/RPMS/x86_64/nginx-1.23.3-1.el7.ngx.x86_64.rpm 
sed -i '/index  index.html index.htm;/a autoindex on;' /etc/nginx/conf.d/default.conf
systemctl start nginx
systemctl status nginx

# создание rpm репозитория
mkdir /usr/share/nginx/html/repo
cp /root/rpmbuild/RPMS/x86_64/nginx-1.23.3-1.el7.ngx.x86_64.rpm /usr/share/nginx/html/repo/
createrepo /usr/share/nginx/html/repo/

 
cat >> /etc/yum.repos.d/custom.repo << EOF
[custom]
name=custom-repo
baseurl=http://192.168.50.10/repo
gpgcheck=0
enabled=1
EOF
