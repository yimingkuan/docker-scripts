#Completely uninstalls DTR from the current Docker instance, if present

docker ps -a | grep dtr | grep -v enzi | awk '{print $1}' | xargs docker rm -f
docker volume ls | grep dtr | awk '{print $2}' | xargs docker volume rm
