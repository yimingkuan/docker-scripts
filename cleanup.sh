#Deletes all stopped containers and dangling volumes matching the parameters, wildcards supported
#usage: ./cleanup.sh [container] [volume]

volume_name = "*"
container_name = "*"

if [ "$2" != "" ]; then
	$volume_name = "$2"
fi

if [ "$1" != "" ]; then
	$container_name = "$1"
fi

docker ps -a | grep 'Exited' | grep $container_name| awk '{print $1}' | xargs --no-run-if-empty docker rm

docker volume ls -qf dangling=true | grep $volume_name | docker volume rm $(docker volume ls -qf dangling=true)
