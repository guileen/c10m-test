# go c10m test

## 空闲连接测试

构建测试服务

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

354MB 65535 个连接，平均每个连接占用 5.4KB，其中一部分由goroutine占用，每个goroutine都至少占用2KB的stack。在实际的应用中，每个连接保存的额外信息也将占用一部分内存。CPU占用很小，因此每台物理机所能承载的空闲连接数主要取决于内存。1百万连接需要5.4G，1千万连接需要54G内存。实际项目中，每个连接还会包含其他信息，会略小于这个数字。

但是实际项目中，仅仅是空闲连接并不能满足我们的要求。因为我们是需要处理有数据往来的连接数，主要的衡量指标是TPS（每秒传输量）和PPS（每秒数据包）。



## C10m问题 by Robert Graham

C10m是继c10k问题之后提出的新问题，指单机1000万连接问题。40gbps网卡、32核、256G内存，这样的配置理论上已经可以处理千万并发连接了。但虽然硬件已经能够满足条件了，但是软件系统依然是复杂的。这就是C10M问题。

Robert Graham的演讲[《C10M Defending The Internet At Scale》(pdf)](https://www.cs.dartmouth.edu/~sergey/cs258/2013/C10M-Defending-the-Internet-at-Scale-Dartmouth-2013.pdf) [(youtube)](https://www.youtube.com/watch?v=D09jdbS6oSI)回答了C10M的问题原因：内核不是解决方案，而是问题本身。最初的C10K之所以成为问题，是因为每个传入的packet都要遍历所有的connection，以找到那个匹配的connection，C10K的解决方案是操作系统修复了这个『bug』，在线程切换、socket查找上保持O(1)的时间。他给除了对C10M问题的定义：

* 千万并发连接
* 每秒百万连接接入
* 10gb/s
* 每秒千万数据包
* 10微秒延迟
* 10微秒抖动
* 10核CPU并行

本节内容摘自他的演讲：

![](/Users/admin/work/guileen.github.com/hexo/source/img/c10m/kernel-map.png)

数据包从网卡到程序经过了一个很复杂的过程。

### User-mode网络栈

* PF_RING/DPDK 使你可以直接获取raw packet而不经过网络协议栈。
  * 对IDS、DNS服务友好
  * 对web server类的服务不友好
* User-mode TCP/IP 协议栈
  * 6windgate 

### 多核问题

大多数代码无法在超过4核的状态下扩展？（really？）

* core-local-data
* ring buffers
* read-copy-update (RCU)

#### 无锁数据结构

* 原子性的修改值（CPU指令）
* 需要特殊的算法来一次修改多个值
* 数据结构：lists、queues、hash tables

#### 缓存失效

大规模情况下，CPU的缓存大量失效。L1 cache 4个cycle（cpu时钟），L2 cache 12个cycle，L3 30 cycles，内存 300 cycles。

分页问题：32G内存需要64M分页表，分页表不匹配缓存，每次缓存未命中消耗加倍。解决方案：2M分页代替4K分页，需要设置启动参数避免内存fregmentation（碎片化？） linux bootparam  hugepages=10000

内核本地数据：

* 不要:用指针管理所有内存数据结构
  * 每次访问指针都是一次缓存失效。
  * [Hash pointer] -> [TCB] -> [Socket] -> [App]
* 要：所有数据放在一整个数据块
  * [TCB | Socket | App]

压缩数据:

* 位数据代替大量integers
* 索引（1~2字节）代替指针（8字节）
* 避免padding数据结构（空值填充？）

缓存友好的数据结构

NUMA架构：加倍内存访问效率。

对象池：

* 每对象、每线程、每socket。避免资源耗尽。

预加载：

* 如：一次解析两个包，预加载下一个hash entry。



## 高性能网络编程系列文章

http://www.52im.net/thread-578-1-1.html

CPU亲和性：linux sched_set_affinity函数绑定CPU核；Linux 提供用户态的numactl, taskset 工具。

linux网络支持的新特性：RSS、RPS、RFS、XPS

kernel优化：net.ipv4.* net.core.* 超时时间调整



## Golang多核并发问题

* reuseport 提供了TCP net.Listener with SO_REUSEPORT, 将线性扩展多核CPU性能。
* 