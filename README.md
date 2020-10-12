# RabbitMQ

针对 [RabbitMQ](https://www.rabbitmq.com) 应用的 Docker 镜像，用于提供 RabbitMQ 服务。

使用说明可参照：[官方说明](https://www.rabbitmq.com/getstarted.html)

![rabbitmq-logo](img/rabbitmq-logo.png)

**版本信息**：

- 3.8、latest （ErLang 22.3.0）
- 3.7 （ErLang 22.3.0）

**镜像信息**

* 镜像地址：colovu/rabbitmq:latest



## **TL;DR**

Docker 快速启动命令：

```shell
$ docker run -d colovu/rabbitmq:3.8
```

Docker-Compose 快速启动命令：

```shell
$ curl -sSL https://raw.githubusercontent.com/colovu/docker-imgname/master/docker-compose.yml > docker-compose.yml

$ docker-compose up -d
```



---



## 默认对外声明

### 端口

- 4369：EarLang epmd 默认端口，用于集群邻居发现（可配置）
- 5671：RabbitMQ AMQP 0.9.1 Clients 使用（可配置）
- 5672：RabbitMQ AMQP 1.0 Clients 使用（可配置）
- 15671：RabbitMQ 默认 HTTPS Web 端口（可配置）
- 25672：RabbitMQ ErLang 分布式节点/工具通讯（可配置）
- 61613：STOMP 插件默认访问端口（可配置）
- 61614：STOMP 插件默认 TLS 访问端口（可配置）
- 1883：MQTT 插件默认访问端口（可配置）
- 8883：MQTT 插件默认 TLS 访问端口（可配置）

### 数据卷

镜像默认提供以下数据卷定义，默认数据分别存储在自动生成的应用名对应`rabbitmq`子目录中：

```shell
/var/log                # RabbitMQ 日志输出
/srv/conf               # RabbitMQ 配置文件
/srv/data               # RabbitMQ 数据存储
```

如果需要持久化存储相应数据，需要**在宿主机建立本地目录**，并在使用镜像初始化容器时进行映射。宿主机相关的目录中如果不存在对应应用 RabbitMQ 的子目录或相应数据文件，则容器会在初始化时创建相应目录及文件。



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

- **RABBITMQ_NODE_NAME**：默认值：**rabbit@localhost**。设置 RabbitMQ 服务节点名称

> 建议为：node@hostname 或 node；在集群中，使用 localhsot 定义节点名时，需要确保为容器定义了一个固定的 hostname ，否则，容器将无法正常工作。

- **RABBITMQ_NODE_PORT_NUMBER**：默认值：**5672**。设置 RabbitMQ 监听服务端口
- **RABBITMQ_NODE_TYPE**：默认值：**stats**。设置 RabbitMQ 服务节点类型。取值范围： *stats*, *queue-ram* or *queue-disc*
- **RABBITMQ_USERNAME**：默认值：**colovu**。设置 RabbitMQ 服务默认用户名
- **RABBITMQ_PASSWORD**：默认值：**pass4colovu**。设置 RabbitMQ 服务默认用户密码。；不与 RABBITMQ_HASHED_PASSWORD 同时设置
- **RABBITMQ_HASHED_PASSWORD**：默认值：**无**。设置 RabbitMQ 服务默认用户密码（hash加密）；不与 RABBITMQ_PASSWORD 同时设置 
- **ENV_DEBUG**：默认值：**false**。设置是否输出容器调试信息。可设置为：1、true、yes

### 集群配置参数

使用 RabbitMQ 镜像，可以很容易的建立一个 RabbitMQ 集群。针对 集群模式，有以下参数可以配置：

- **RABBITMQ_CLUSTER_NODE_NAME**：默认值：**无**。定义当前节点加入的 RabbitMQ 集群名，如：`clusternode@hostname`
- **RABBITMQ_CLUSTER_PARTITION_HANDLING**：默认值：**ignore**。设置集群的分区信息恢复机制
- **RABBITMQ_ERL_COOKIE**：默认值：**无**。设置集群中用于交互的 Cookie，以确认哪些服务器可以相互通讯。只有 Cookie 相同的服务器才可以互相访问

### 可选配置参数

如果没有必要，可选配置参数可以不用定义，直接使用对应的默认值，主要包括：

- **RABBITMQ_DISK_FREE_LIMIT**：默认值：**{mem_relative, 1.0}**。设置应用磁盘占用的空闲空间限制
- **RABBITMQ_MANAGER_BIND_IP**：默认值：**0.0.0.0**。设置管理后台绑定的 IP 地址。容器中默认不需要配置
- **RABBITMQ_MANAGER_PORT_NUMBER**：默认值：**15672**。设置 RabbitMQ 管理服务的端口
- **RABBITMQ_VHOST**：默认值：**/**。设置应用虚拟主机根路径
- **RABBITMQ_ENABLE_PLUGINS**：默认值：**无**。设置启用的插件。如：rabbitmq_mqtt、rabbitmq_tracing、rabbitmq_web_mqtt、syslog等

> rabbitmq_auth_backend_ldap、rabbitmq_management不在这里设置；使用对应功能启用。
>

- ~~`RABBITMQ_VM_MEMORY_HIGH_WATERMARK`~~：默认值：**无**。参见[官方文档](https://www.rabbitmq.com/memory.html#memsup-usage)。暂时未起作用

### STOMP 配置参数

在使用参数`RABBITMQ_ENABLE_PLUGINS`启用`rabbitmq_stomp`插件后，以下配置参数有效：

- **RABBITMQ_STOMP_USERNAME**：默认值：**admin**
- **RABBITMQ_STOMP_PASSWORD**：默认值：**colovu**
- **RABBITMQ_STOMP_VHOST**：默认值：**RABBITMQ_VHOST**设置的值
- **RABBITMQ_STOMP_PORT_NUMBER**：默认值：**61613**

### LDAP 配置参数

在配置服务器使用 LDAP 做相关数据存储及验证时，可以使用以下参数配置相关的 LDAP 服务器信息：

- **RABBITMQ_ENABLE_LDAP**：默认值：**no**。配置是否启用 LDAP 支持
- **RABBITMQ_LDAP_SERVER**：默认值：**无**。服务器地址或主机名
- **RABBITMQ_LDAP_SERVER_PORT**：默认值：**389**。LDAP 服务端口
- **RABBITMQ_LDAP_USER_DN_PATTERN**：默认值：**无**。RabbitMQ 绑定 LDAP 时使用的 DN，如：`cn=$${username},dc=example,dc=org`

> 注意：需要使用`$$`以在参数中输出`$`

- **RABBITMQ_LDAP_TLS**：默认值：**no**。配置是否启用 TLS 加密传输

### TLS 配置参数

- **RABBITMQ_SSL_CERT_FILE**：默认值：**无**。本机证书文件
- **RABBITMQ_SSL_KEY_FILE**：默认值：**无**。本机私钥文件
- **RABBITMQ_SSL_CA_FILE**：默认值：**无**。CA证书文件



## 安全

### 用户及密码

RabbitMQ 镜像默认设置了用户`colovu`及对应的密码`pass4colovu`，在实际生产环境中建议使用自定义的用户名及密码控制访问。

### 容器安全

本容器默认使用应用对应的运行时用户及用户组运行应用，以加强容器的安全性。在使用非`root`用户运行容器时，相关的资源访问会受限；应用仅能操作镜像创建时指定的路径及数据。使用`Non-root`方式的容器，更适合在生产环境中使用。



## 注意事项

- 容器中启动参数不能配置为后台运行，只能使用前台运行方式，即：`daemonize no`
- 如果应用使用后台方式运行，则容器的启动命令会在运行后自动退出，从而导致容器退出



----

本文原始来源 [Endial Fang](https://github.com/colovu) @ [Github.com](https://github.com)
