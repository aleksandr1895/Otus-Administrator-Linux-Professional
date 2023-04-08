Цель домашнего задания
----------------------
Разобраться с основами docker, с образом, эко системой docker в целом.

Описание домашнего задания
--------------------------
```
1. Написать Dockerfile на базе apache/nginx который будет содержать две статичные web-страницы на разных портах. Например, 80 и 3000.
2. Пробросить эти порты на хост машину. Обе страницы должны быть доступны по адресам
localhost:80 и localhost:3000
3. Добавить 2 вольюма. Один для логов приложения, другой для web-страниц.
```
Для начала устанавливаем Docker c официального сайта https://docs.docker.com/engine/install/centos/

Будем устанавливать с репозитория    
Set up the repository    
```
sudo yum install -y yum-utils
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
```
Install Docker Engine    
``sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin``    
Start Docker    
```
sudo systemctl start docker

docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; disabled; vendor pre>
   Active: active (running) since Fri 2023-04-07 09:07:04 MSK; 1h 16min ago
     Docs: https://docs.docker.com
 Main PID: 1425 (dockerd)
    Tasks: 8
   Memory: 108.9M
   CGroup: /system.slice/docker.service
           └─1425 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/contai>
```
Docker Engine installation is successful by running the hello-world image.    

``sudo docker run hello-world``

Docker установлен приступаем к созданию Dockerfile    

 ### Написать Dockerfile на базе apache/nginx который будет содержать две статичные web-страницы на разных портах. Например, 80 и 3000.
```
vi Dockerfile

    # Используем базовый образ Nginx
    FROM nginx
    # Устанавливаем директорию для статических файлов
    WORKDIR /usr/share/nginx/html
    # Копируем две статические страницы в директорию
    COPY index.html index.html
    COPY about.html about.html
    # Пробрасываем порты 80 и 3000 на хост машину
    EXPOSE 80
    EXPOSE 3000
    # Добавляем два вольюма. Один для логов приложения, другой для web-страниц
    VOLUME /var/log/nginx
    VOLUME /usr/share/nginx/html
    # Копируем файл конфигурации Nginx
    COPY nginx.conf /etc/nginx/nginx.conf
    # Запускаем Nginx в фоновом режиме
    CMD ["nginx", "-g", "daemon off;"]
```
Собираем Docker образ с Dockerfile    

`` docker build -t mynginx . ``    
```
[+] Building 6.6s (10/10) FINISHED                                              
 => [internal] load build definition from Dockerfile                       1.7s
 => => transferring dockerfile: 909B                                       0.4s
 => [internal] load .dockerignore                                          1.0s
 => => transferring context: 2B                                            0.1s
 => [internal] load metadata for docker.io/library/nginx:latest            3.6s
 => [1/5] FROM docker.io/library/nginx@sha256:2ab30d6ac53580a6db8b657abf0  0.0s
 => [internal] load build context                                          0.7s
 => => transferring context: 270B                                          0.0s
 => CACHED [2/5] WORKDIR /usr/share/nginx/html                             0.0s
 => CACHED [3/5] COPY index.html index.html                                0.0s
 => CACHED [4/5] COPY about.html about.html                                0.0s
 => CACHED [5/5] COPY nginx.conf /etc/nginx/nginx.conf                     0.0s
 => exporting to image                                                     0.2s
 => => exporting layers                                                    0.0s
 => => writing image sha256:4f27935b9ee133b521eef419cebca2720451c6899ca1b  0.2s
 => => naming to docker.io/library/mynginx                                 0.0s
```
### Пробрасываем порты 80, 3000 на хост машину и добавляем 2 вольюма и запускаем контейнер
```
docker run -d -p 80:80 -p 3000:3000 -v /path/to/logs:/var/log/nginx -v /path/to/html:/usr/share/nginx/html mynginx

(-d) Запуск контейнера в фоновом режиме    
(-p) Пробрасывает порты 80 и 3000 на хост машину    
(-v) Добавляет два вольюма    
```

``/path/to/logs`` это путь к директории, в которой будут храниться логи     Nginx,                                                                               ``/path/to/html`` это путь к директории, в которой хранятся ваши статические веб-страницы.    
```
docker ps

CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                                                                          NAMES
67751d2f0afb   mynginx   "/docker-entrypoint.…"   18 seconds ago   Up 12 seconds   0.0.0.0:80->80/tcp, :::80->80/tcp, 0.0.0.0:3000->3000/tcp, :::3000->3000/tcp   trusting_panini
```

Запускаем  http://localhost:80 и http://localhost:3000