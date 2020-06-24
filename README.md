# RabbitMQ

针对 RabbitMQ 应用的 Docker 镜像，用于提供 RabbitMQ 服务。

详细信息可参照官网：https://www.rabbitmq.com/



**版本信息**：

- 3.8、3.8.3、latest （ErLang 22.3.0）
- 3.7、3.7.25 （ErLang 22.3.0）

**镜像信息**

* 镜像地址：colovu/rabbitmq:latest
  * 依赖镜像：colovu/ubuntu:latest

**使用 Docker Compose 运行应用**

可以使用 Git 仓库中的默认`docker-compose.yml`，快速启动应用进行测试：

```shell
$ curl -sSL https://raw.githubusercontent.com/colovu/docker-rabbitmq/master/docker-compose.yml > docker-compose.yml

$ docker-compose up -d
```



## 默认对外声明

### 端口

- 4369 5671 5672 15672 25672：端口用途

### 数据卷

镜像默认提供以下数据卷定义，默认数据存储在自动生成的应用名对应子目录中：

```shell
/var/log			# 日志输出
/srv/conf			# 配置文件
/srv/data			# 数据存储
```

如果需要持久化存储相应数据，需要在宿主机建立本地目录，并在使用镜像初始化容器时进行映射。

举例：

- 使用宿主机`/host/dir/to/conf`存储配置文件
- 使用宿主机`/host/dir/to/data`存储数据文件
- 使用宿主机`/host/dir/to/log`存储日志文件

创建以上相应的宿主机目录后，容器启动命令中对应的数据卷映射参数类似如下：

```shell
-v /host/dir/to/conf:/srv/conf -v /host/dir/to/data:/srv/data -v /host/dir/to/log:/var/log
```

使用 Docker Compose 时配置文件类似如下：

```yaml
services:
  rabbitmq:
  ...
    volumes:
      - /host/dir/to/conf:/srv/conf
      - /host/dir/to/data:/srv/data
      - /host/dir/to/log:/var/log
  ...
```

> 注意：应用需要使用的子目录会自动创建。



## 使用说明

- 在后续介绍中，启动的容器默认命名为`rabbitmq`、`rabbitmq1`、`rabbitmq2`，需要根据实际情况修改
- 在后续介绍中，容器默认使用的网络命名为`app-tier`，需要根据实际情况修改



### 容器网络

在工作在同一个网络组中时，如果容器需要互相访问，相关联的容器可以使用容器初始化时定义的名称作为主机名进行互相访问。

创建网络：

```shell
$ docker network create app-tier --driver bridge
```

- 使用桥接方式，创建一个命名为`app-tier`的网络



如果使用已创建的网络连接不同容器，需要在启动命令中增加类似`--network app-tier`的参数。使用 Docker Compose 时，在`docker-compose`的配置文件中增加：

```yaml
services:
	rabbitmq:
		...
		networks:
    	- app-tier
  ...
```



### 下载镜像

可以不单独下载镜像，如果镜像不存在，会在初始化容器时自动下载。

```shell
# 下载指定Tag的镜像
$ docker pull colovu/rabbitmq:tag

# 下载最新镜像
$ docker pull colovu/rabbitmq:latest
```

> TAG：替换为需要使用的指定标签名



### 持久化数据存储

如果需要将容器数据持久化存储至宿主机或数据存储中，需要确保宿主机对应的路径存在，并在启动时，映射为对应的数据卷。

RabbitMQ 镜像默认配置了用于应用配置的数据卷 `/srv/conf`及用于存储数据的数据卷`/srv/data`。可以使用宿主机目录映射相应的数据卷，将数据持久化存储在宿主机中。路径中，应用对应的子目录如果不存在，容器会在初始化时创建，并生成相应的默认文件。

> 注意：将数据持久化存储至宿主机，可避免容器销毁导致的数据丢失。同时，将数据存储及数据日志分别映射为不同的本地设备（如不同的共享数据存储）可提供较好的性能保证。



### 实例化服务容器

生成并运行一个新的容器：

```shell
 docker run -d --name rabbitmq colovu/rabbitmq:latest
```

- `-d`: 使用服务方式启动容器
- `--name rabbitmq`: 为当前容器命名



使用数据卷映射生成并运行一个容器：

```shell
 $ docker run -d --name rabbitmq \
  -v /host/dir/to/data:/srv/data \
  -v /host/dir/to/conf:/srv/conf \
  colovu/rabbitmq:latest
```



### 连接容器

启用 [Docker container networking](https://docs.docker.com/engine/userguide/networking/)后，工作在容器中的 RabbitMQ 服务可以被其他应用容器访问和使用。

#### 命令行方式

使用已定义网络`app-tier`，启动 RabbitMQ 容器：

```shell
$ docker run -d --name rabbitmq-server \
	--network app-tier \
	colovu/rabbitmq:latest
```

- `--network app-tier`: 容器使用的网络



使用客户端容器链接，并查询服务器状态：

```shell
$ docker run -it --rm \
    --network app-tier \
    colovu/rabbitmq:latest rabbitmqctl -n rabbit@rabbitmq-server status
```



其他业务容器连接至 RabbitMQ 容器：

```shell
$ docker run -d --name other-app --network app-tier --link rabbitmq1:rabbitmq -d other-app-image:tag
```

- `--link rabbitmq1:rabbitmq`: 链接 `rabbitmq1` 容器，并命名为`rabbitmq`进行使用（如果其他容器中使用了该名称进行访问）



#### Docker Compose 方式

如使用配置文件`docker-compose-test.yml`:

```yaml
version: '3.6'

services:
  rabbitmq:
    image: 'colovu/rabbitmq:latest'
    networks:
      - app-tier
  myapp:
    image: 'other-app-img:tag'
    links:
    	- rabbitmq:rabbitmq
    networks:
      - app-tier
      
networks:
  app-tier:
    driver: bridge
```

> 注意：
>
> - 需要修改 `other-app-img:tag`为相应业务镜像的名字
> - 在其他的应用中，使用`rabbitmq`连接 RabbitMQ 容器，如果应用不是使用的该名字，可以重定义启动时的命名，或使用`--links name:name-in-container`进行名称映射

启动方式：

```shell
$ docker-compose up -d -f docker-compose-test.yml
```

- 如果配置文件命名为`docker-compose.yml`，可以省略`-f docker-compose-test.yml`参数



#### 其他连接操作

使用 exec 命令访问容器ID或启动时的命名，进入容器并执行命令：

```shell
$ docker exec -it rabbitmq /bin/bash
```

- `/bin/bash`: 在进入容器后，运行的命令



使用 attach 命令进入已运行的容器：

```shell
$ docker attach --sig-proxy=false rabbitmq
```

- **该方式无法执行命令**，仅用于通过日志观察应用运行状态
- 如果不使用` --sig-proxy=false`，关闭终端或`Ctrl + C`时，会导致容器停止



### 停止容器

使用容器ID或启动时的命名（本例中命名为`rabbitmq`）停止：

```shell
docker stop rabbitmq
```



## Docker Compose 部署



### 单机部署

根据需要，修改 Docker Compose 配置文件，如`docker-compose.yml`，并启动:

```bash
$ docker-compose up -d
```

- 在不定义配置文件的情况下，默认使用当前目录的`docker-compose.yml`文件
- 如果配置文件为其他名称，可以使用`-f 文件名`方式指定



`docker-compose.yml`文件参考如下：

```yaml
version: '3.6'

services:
  rabbitmq:
    image: colovu/rabbitmq:latest
	volumes:
      - '/tmp/data:/srv/data'
      - '/tmp/conf:/srv/conf'
```



#### 环境验证





### 集群部署

根据需要，修改 Docker Compose 配置文件，如`docker-compose-cluster.yml`，并启动:

```bash
$ docker-compose -f docker-compose-cluster.yml up -d
```

- 在不定义配置文件的情况下，默认使用当前目录的`docker-compose.yml`文件



配置 RabbitMQ 集群时，需要首先创建类型为`state`的主节点，其他节点加入该节点，并组成集群；其他节点分为`queue-disc`和`queue-ram`两种。

可以使用 [`docker stack deploy`](https://docs.docker.com/engine/reference/commandline/stack_deploy/) 或 [`docker-compose`](https://github.com/docker/compose) 方式，启动一组服务容器。 `docker-compose.yml` 配置文件（伪集群）参考如下：

```yaml
version: '3.6'

services:
  stats:
    image: 'colovu/rabbitmq:latest'
    environment:
      - RABBITMQ_NODE_TYPE=stats
      - RABBITMQ_NODE_NAME=rabbit@stats
      - RABBITMQ_ERL_COOKIE=s3cr3tc00ki3
    ports:
      - '15672:15672'
    volumes:
      - 'rabbitmqstats_data:/srv/data'
  queue-disc1:
    image: 'colovu/rabbitmq:latest'
    environment:
      - RABBITMQ_NODE_TYPE=queue-disc
      - RABBITMQ_NODE_NAME=rabbit@queue-disc1
      - RABBITMQ_CLUSTER_NODE_NAME=rabbit@stats
      - RABBITMQ_ERL_COOKIE=s3cr3tc00ki3
    volumes:
      - 'rabbitmqdisc1_data:/srv/data'
  queue-ram1:
    image: 'colovu/rabbitmq:latest'
    environment:
      - RABBITMQ_NODE_TYPE=queue-ram
      - RABBITMQ_NODE_NAME=rabbit@queue-ram1
      - RABBITMQ_CLUSTER_NODE_NAME=rabbit@stats
      - RABBITMQ_ERL_COOKIE=s3cr3tc00ki3
    volumes:
      - 'rabbitmqram1_data:/srv/data'

volumes:
  rabbitmqstats_data:
    driver: local
  rabbitmqdisc1_data:
    driver: local
  rabbitmqram1_data:
    driver: local
```

> 由于配置的是伪集群模式, 所以各个 server 的端口参数必须不同（使用同一个宿主机的不同端口）



#### 环境验证



## 容器配置

在初始化 RabbitMQ 容器时，如果配置文件不存在，可以在命令行中使用`-e VAR_NAME=VALUE`参数对默认参数进行修改。类似命令如下：

```shell
$ docker run -d -e "RABBITMQ_PASSWORD=my_password" --name rabbitmq colovu/rabbitmq:latest
```

在 Docker Compose 配置文件中类似如下：

```yaml
rabbitmq:
  ...
  environment:
    - RABBITMQ_PASSWORD=my_password
  ...
```



### 常规配置参数

常使用的环境变量主要包括：

#### `RABBITMQ_NODE_NAME`

默认值：**rabbit@localhost**。设置 RabbitMQ 服务节点名称。

> 建议为：node@hostname 或 node；在集群中，使用 localhsot 定义节点名时，需要确保为容器定义了一个固定的 hostname ，否则，容器将无法正常工作。

#### `RABBITMQ_NODE_PORT_NUMBER`

默认值：**5672**。设置 RabbitMQ 服务端口。

#### `RABBITMQ_NODE_TYPE`

默认值：**stats**。设置 RabbitMQ 服务节点类型。

> 取值范围： *stats*, *queue-ram* or *queue-disc*

#### `RABBITMQ_USERNAME`

默认值：**colovu**。设置 RabbitMQ 服务默认用户名。

#### `RABBITMQ_PASSWORD`

默认值：**pass4colovu**。设置 RabbitMQ 服务默认用户密码。；不与 RABBITMQ_HASHED_PASSWORD 同时设置 。

#### `RABBITMQ_HASHED_PASSWORD`

默认值：**无**。设置 RabbitMQ 服务默认用户密码（hash加密）；不与 RABBITMQ_PASSWORD 同时设置 。

#### `ENV_DEBUG`

默认值：**false**。设置是否输出容器调试信息。

> 可设置为：1、true、yes



### 集群配置参数

使用 RabbitMQ 镜像，可以很容易的建立一个 RabbitMQ 集群。针对 集群模式，有以下参数可以配置：

#### `RABBITMQ_CLUSTER_NODE_NAME`

默认值：**无**。定义当前节点加入的 RabbitMQ 集群名，如：`clusternode@hostname`。

#### `RABBITMQ_CLUSTER_PARTITION_HANDLING`

默认值：**ignore**。设置集群的分区信息恢复机制。

#### `RABBITMQ_ERL_COOKIE`

默认值：**无**。设置集群中用于交互的 Cookie，以确认哪些服务器可以相互通讯。



### 可选配置参数

如果没有必要，可选配置参数可以不用定义，直接使用对应的默认值，主要包括：

#### `RABBITMQ_CONF_DIR`

默认值：**/srv/conf/rabbitmq**。设置应用的数据存储目录。

#### `RABBITMQ_DATA_DIR`

默认值：**/srv/data/rabbitmq**。设置应用的数据日志存储目录。

#### `RABBITMQ_LOG_DIR`

默认值：**/var/log/rabbitmq**。设置应用的日志存储目录。

#### `RABBITMQ_DAEMON_USER`

默认值：**rabbitmq**。设置默认运行应用的系统用户。

#### `RABBITMQ_DAEMON_GROUP`

默认值：**rabbitmq**。设置默认运行应用的用户所在系统分组。

#### `RABBITMQ_DISK_FREE_LIMIT`

默认值：**{mem_relative, 1.0}**。设置应用磁盘占用的空闲空间限制。

#### `RABBITMQ_MANAGER_BIND_IP`

默认值：**0.0.0.0**。设置管理后台绑定的 IP 地址。

#### `RABBITMQ_MANAGER_PORT_NUMBER`

默认值：**15672**。设置 RabbitMQ 管理服务的端口。

#### `RABBITMQ_VHOST`

默认值：**/**。设置应用虚拟主机根路径。

#### `RABBITMQ_ENABLE_PLUGINS`

默认值：**无**。设置启用的插件。

> rabbitmq_auth_backend_ldap、rabbitmq_management不在这里设置；使用对应功能启用。
>
> 如：rabbitmq_mqtt、rabbitmq_tracing、rabbitmq_web_mqtt、syslog等

#### ~~`RABBITMQ_VM_MEMORY_HIGH_WATERMARK`~~

默认值：**无**。参见[官方文档](https://www.rabbitmq.com/memory.html#memsup-usage)。暂时未起作用



### LDAP配置参数

在配置服务器使用 LDAP 做相关数据存储及验证时，可以使用以下参数配置相关的 LDAP 服务器信息：

#### `RABBITMQ_ENABLE_LDAP`

默认值：**no**。配置是否启用 LDAP 支持。

#### `RABBITMQ_LDAP_SERVER`

默认值：**无**。服务器地址或主机名。

#### `RABBITMQ_LDAP_SERVER_PORT`

默认值：**389**。LDAP 服务端口。

#### ``RABBITMQ_LDAP_USER_DN_PATTERN``

默认值：**无**。RabbitMQ 绑定 LDAP 时使用的 DN，如：`cn=$${username},dc=example,dc=org`。

> 注意：需要使用`$$`以在参数中输出`$`

#### `RABBITMQ_LDAP_TLS`

默认值：**no**。配置是否启用 TLS 加密传输。

#### `RABBITMQ_SSL_CERT_FILE`

默认值：**无**。本机证书文件。

#### `RABBITMQ_SSL_KEY_FILE`

默认值：**无**。本机私钥文件。

#### `RABBITMQ_SSL_CA_FILE`

默认值：**无**。CA证书文件。



### 应用配置文件

应用配置文件默认存储在容器内的`/srv/conf/rabbitmq/`目录中。

#### 使用已有配置文件

RabbitMQ 容器的配置文件默认存储在数据卷`/srv/conf`中，子路径为`rabbitmq`。有以下两种方式可以使用自定义的配置文件：

- 直接映射配置文件

```shell
$ docker run -d --restart always --name rabbitmq -v $(pwd)/rabbitmq.config:/srv/conf/rabbitmq/rabbitmq.config colovu/rabbitmq:latest
```

- 映射配置文件数据卷

```shell
$ docker run -d --restart always --name rabbitmq -v $(pwd):/srv/conf colovu/rabbitmq:latest
```

> 第二种方式时，本地路径中需要包含 rabbitmq 子目录，且相应文件存放在该目录中



#### 生成配置文件并修改

对于没有本地配置文件的情况，可以使用以下方式进行配置。

##### 使用镜像初始化容器

使用宿主机目录映射容器数据卷，并初始化容器：

```shell
$ docker run -d --restart always --name rabbitmq -v /host/path/to/conf:/srv/conf colovu/rabbitmq:latest
```

or using Docker Compose:

```yaml
version: '3.6'

services:
  rabbitmq:
    image: 'colovu/rabbitmq:latest'
    volumes:
      - /host/path/to/conf:/srv/conf
```

##### 修改配置文件

在宿主机中修改映射目录`/host/path/to/conf`下子目录`rabbitmq`中的配置文件（如 `rabbitmq.config`）。

##### 重新启动容器

在修改配置文件后，重新启动容器，以使修改的内容起作用：

```shell
$ docker restart rabbitmq
```

或者使用 Docker Compose：

```shell
$ docker-compose restart rabbitmq
```



## 日志

默认情况下，Docker 镜像配置为将容器日志直接输出至`stdout`，可以使用以下方式查看：

```bash
$ docker logs rabbitmq
```

使用 Docker Compose 管理时，使用以下命令：

```bash
$ docker-compose logs rabbitmq
```



实际使用时，可以配置将相应信息输出至`/var/log`数据卷的相应文件中：

```shell
$ docker run -d --restart always --name rabbitmq -v /host/path/to/log:/var/log colovu/rabbitmq:latest
```

使用该配置后，相应的日志文件，将会存储在数据卷`/host/path/to/log`的相应文件中。

容器默认使用的日志驱动为 `json-file`，如果需要使用其他驱动，可以使用`--log-driver`进行修改，详细说明请参见文档 [logging driver](https://docs.docker.com/engine/admin/logging/overview/) 中说明。



## 容器维护

### 容器数据备份

默认情况下，镜像都会提供`/srv/data`数据卷持久化保存数据。如果在容器创建时，未映射宿主机目录至容器，需要在删除容器前对数据进行备份，否则，容器数据会在容器删除后丢失。

如果需要备份数据，可以使用按照以下步骤进行：

#### 停止当前运行的容器

如果使用命令行创建的容器，可以使用以下命令停止：

```bash
$ docker stop rabbitmq
```

如果使用 Docker Compose 创建的，可以使用以下命令停止：

```bash
$ docker-compose stop rabbitmq
```

#### 执行备份命令

在宿主机创建用于备份数据的目录`/path/to/back-up`，并执行以下命令：

```bash
$ docker run --rm -v /path/to/back-up:/backups --volumes-from rabbitmq busybox \
  cp -a /srv/data/rabbitmq /backups/
```

如果容器使用 Docker Compose 创建，执行以下命令：

```bash
$ docker run --rm -v /path/to/back-up:/backups --volumes-from `docker-compose ps -q rabbitmq` busybox \
  cp -a /srv/data/rabbitmq /backups/
```



### 容器数据恢复

在容器创建时，如果未映射宿主机目录至容器数据卷，则容器会创建私有数据卷。如果是启动新的容器，可直接使用备份的数据进行数据卷映射，命令类似如下：

```bash
$ docker run -v /path/to/back-up:/srv/data colovu/rabbitmq:latest
```

使用 Docker Compose 管理时，可直接在`docker-compose.yml`文件中指定：

```yaml
zoo1:
	volumes:
		- /path/to/back-up:/srv/data
```



### 镜像更新

针对当前镜像，会根据需要不断的提供更新版本。针对更新版本（大版本相同的情况下，如果大版本不同，需要参考指定说明处理），可使用以下步骤使用新的镜像创建容器：

#### 获取新版本的镜像

```bash
$ docker pull colovu/rabbitmq:TAG
```

这里`TAG`为指定版本的标签名，如果使用最新的版本，则标签为`latest`。

#### 停止容器并备份数据

如果容器未使用宿主机目录映射为容器数据卷的方式创建，参照`容器数据备份`中方式，备份容器数据。

如果容器使用宿主机目录映射为容器数据卷的方式创建，不需要备份数据。

#### 删除当前使用的容器

```bash
$ docker rm -v rabbitmq
```

使用 Docker Compose 管理时，使用以下命令：

```bash
$ docker-compose rm -v rabbitmq
```

#### 使用新的镜像启动容器

将宿主机备份目录映射为容器数据卷，并创建容器：

```bash
$ docker run --name rabbitmq -v /path/to/back-up:/srv/data colovu/rabbitmq:TAG
```

使用 Docker Compose 管理时，确保`docker-compose.yml`文件中包含数据卷映射指令，使用以下命令启动：

```bash
$ docker-compose up rabbitmq
```



## 注意事项

- 容器中启动参数不能配置为后台运行，只能使用前台运行方式，即：`daemonize no`
- 如果应用使用后台方式运行，则容器的启动命令会在运行后自动退出，从而导致容器退出



----

本文原始来源 [Endial Fang](https://github.com/colovu) @ [Github.com](https://github.com)
