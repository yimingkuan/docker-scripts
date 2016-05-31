#TODO: add multiple options for container removal. Currently removes all exited containers

docker ps -a | grep 'Exited' | awk '{print $1}' | xargs --no-run-if-empty docker rm
