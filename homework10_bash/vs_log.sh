#!/bin/bash

# Проверка наличия лог файла
if [ ! -r "$1" ] ; then 
	echo "Error: log file $1 not found." >&2
	exit 1
fi

# lockfile
lock_file=./lock_file
if [ -f $lock_file ]; then
    echo Job is already running\!
    exit 1
else
    echo "PID: $$" > $lock_file
    trap 'rm -f "$lock_file"; exit $?' INT TERM EXIT
fi
touch $lock_file


#Временный диапозон 
timeH=$(cat access-4560-644067.log | awk '{print $4}' | head -n 1 &&  date | awk '{print $2,$3,$4,$6}')
# Список IP адресов (с наибольшим кол-вом запросов)
IP=$(cat access-4560-644067.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -n 10)  
# Список запрашиваемых URL (с наибольшим кол-вом запросов)
URL=$(cat access-4560-644067.log | awk '{print $7}' | sort | uniq -c | sort -rn | head -n 10)
# Ошибки веб-сервера/приложения
ERR=$(cat access-4560-644067.log | awk '{print $9}' | grep ^4 | sort | uniq -d -c | sort -rn) 
ERoR=$(cat access-4560-644067.log | egrep -wi 'Error') 
# Список всех кодов HTTP ответа с указанием их кол-ва
COD=$(cat access-4560-644067.log | awk '{print $9}'| grep -v "-" | sort | uniq -c | sort -rn | head -n 10)

echo -e "Данные за период:$timeH\n"Список IP адресов"\n$IP\n\n"Список запрашиваемых URL"\n$URL\n\n"Ошибки веб-сервера"\n$ERR\n\n$ERoR\n\n"Список всех кодов HTTP ответа с указанием их кол-ва"\n$COD\n" | mail -s "Log server Info" root@localhost

 
# release lock
rm -f $lock_file
trap - INT TERM EXIT
