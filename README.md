# go C10m 模拟测试


构建服务

	./build.sh

测试方法，使用docker模拟大量的连接。首先创建一个docker网络c10m

	docker network create --driver bridge --subnet 172.31.0.0/16 c10m
	docker run --network c10m --ip 172.31.0.2 -v $(pwd)/server:/server --name c10m_server alpine /server

运行客户端

	./setup.sh 20000 50 172.31.0.2

我们可以看到服务端输出:

	2021/04/19 11:46:49 total number of connections: 100
	2021/04/19 11:46:49 total number of connections: 200
	2021/04/19 11:46:49 total number of connections: 300
	2021/04/19 11:46:49 total number of connections: 400
	2021/04/19 11:46:49 total number of connections: 500
	2021/04/19 11:46:50 total number of connections: 600
	2021/04/19 11:46:50 total number of connections: 700

