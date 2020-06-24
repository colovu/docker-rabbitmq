#!/bin/bash -e

# 在安装完应用后，使用该脚本修改默认配置文件中部分配置项
# 如果相应的配置项已经定义整体环境变量，则不需要在这里修改
echo "Process overrides for default configs..."
#sed -i -e '/^listeners=/d' "$KAFKA_HOME/config/server.properties"
sed -i -e 's/^SYS_PREFIX=.*$/SYS_PREFIX=/g' "$APP_HOME_DIR/sbin/rabbitmq-defaults"

sed -i -e 's/^CONFIG_FILE=.*$/CONFIG_FILE=\/srv\/conf\/rabbitmq\/rabbitmq.config/g' "$APP_HOME_DIR/sbin/rabbitmq-defaults"
sed -i -e 's/^MNESIA_BASE=.*$/MNESIA_BASE=\/srv\/data\/rabbitmq\/mnesia/g' "$APP_HOME_DIR/sbin/rabbitmq-defaults"
sed -i -e 's/^GENERATED_CONFIG_DIR=.*$/GENERATED_CONFIG_DIR=\/srv\/conf\/rabbitmq/g' "$APP_HOME_DIR/sbin/rabbitmq-defaults"
sed -i -e 's/^CONF_ENV_FILE=.*$/CONF_ENV_FILE=\/srv\/conf\/rabbitmq\/rabbitmq-env.conf/g' "$APP_HOME_DIR/sbin/rabbitmq-defaults"
# 修改默认Log输出目录
#sed -i -e 's/^log.dirs=\/tmp\/kafka-logs*/log.dirs=\/var\/log\/kafka/g' "$KAFKA_HOME/config/server.properties"