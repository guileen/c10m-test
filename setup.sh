#!/bin/bash

CONNECTIONS=$1
REPLICAS=$2
IP=$3

#docker stop $(docker images | grep 'c10m')
#docker rmi $(docker images | grep 'c10m')

docker network create --driver bridge --subnet 172.31.0.0/16 c10m

docker run --network c10m --ip ${IP} -v $(pwd)/server:/server --privileged --name c10mserver --ulimit nofile=1000000:1000000 -d alpine sh -c 'sysctl -w net.netfilter.nf_conntrack_max=1000000 && /server'

#go build --tags "static netgo" -o client client.go
for (( c=0; c<${REPLICAS}; c++ ))
do
    docker run --network c10m -v $(pwd)/client/client:/client --name c10mclient_$c -d alpine /client \
    -conn=${CONNECTIONS} -ip=${IP}
done
