#Deletes all stopped containers and dangling volumes matching the parameters, wildcards supported
#usage: ./cleanup.sh [container] [volume]
#TODO: Add alternative for 'xargs -r' for OSX

set -e

volume_name=""
container_name=""

if [ "$2" != "" ]; then
	volume_name="$2"
fi

if [ "$1" != "" ]; then
	container_name="$1"
fi

cleanup () {
	docker ps -a | grep 'Exited' | grep "$container_name" | awk '{print $1}' | xargs -r docker rm
	
	docker volume ls -qf dangling=true | grep "$volume_name" | awk '{print $1}' | xargs -r docker volume rm
}

cleanup
