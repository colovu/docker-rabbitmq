#!/bin/bash -e
#
# 在安装完应用后，使用该脚本修改默认配置文件中部分配置项; 如果相应的配置项已经定义为容器环境变量，则不需要在这里修改

# 定义要修改的文件
CONF_FILE="${APP_HOME_DIR}/sbin/rabbitmq-defaults"

echo "Process overrides for: ${CONF_FILE}"
#sed -i -e '/^listeners=/d' "$KAFKA_HOME/config/server.properties"
sed -i -E 's/^SYS_PREFIX=.*$/SYS_PREFIX=/g' "$CONF_FILE"

sed -i -E 's/^CONFIG_FILE=.*$/CONFIG_FILE=\/srv\/conf\/rabbitmq\/rabbitmq.config/g' "$CONF_FILE"
sed -i -E 's/^LOG_BASE=.*$/LOG_BASE=\/var\/log\/rabbitmq/g' "$CONF_FILE"
sed -i -E 's/^MNESIA_BASE=.*$/MNESIA_BASE=\/srv\/data\/rabbitmq\/mnesia/g' "$CONF_FILE"
sed -i -E 's/^GENERATED_CONFIG_DIR=.*$/GENERATED_CONFIG_DIR=\/srv\/conf\/rabbitmq/g' "$CONF_FILE"
sed -i -E 's/^CONF_ENV_FILE=.*$/CONF_ENV_FILE=\/srv\/conf\/rabbitmq\/rabbitmq-env.conf/g' "$CONF_FILE"
# 修改默认Log输出目录
#sed -i -e '/^log.dirs=\/tmp\/kafka-logs*/log.dirs=\/var\/log\/kafka/g' "$KAFKA_HOME/config/server.properties"
