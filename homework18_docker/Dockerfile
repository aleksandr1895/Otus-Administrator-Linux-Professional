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
