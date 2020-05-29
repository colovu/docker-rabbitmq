#!/bin/bash
#
# 应用通用业务处理函数

# 加载依赖脚本
. /usr/local/bin/colovu/cv-log.sh
. /usr/local/bin/colovu/cv-file.sh
. /usr/local/bin/colovu/cv-fs.sh
. /usr/local/bin/colovu/cv-os.sh
. /usr/local/bin/colovu/cv-validations.sh

# 函数列表

# 将变量配置更新至配置文件
# 参数:
#   $1 - 文件
#   $2 - 变量
#   $3 - 值（列表）
kafka_common_conf_set() {
    local file="${1:?missing file}"
    local key="${2:?missing key}"
    shift
    shift
    local values=("$@")

    if [[ "${#values[@]}" -eq 0 ]]; then
        LOG_E "missing value"
        return 1
    elif [[ "${#values[@]}" -ne 1 ]]; then
        for i in "${!values[@]}"; do
            kafka_common_conf_set "$file" "${key[$i]}" "${values[$i]}"
        done
    else
        value="${values[0]}"
        # Check if the value was set before
        if grep -q "^[#\\s]*$key\s*=.*" "$file"; then
            # Update the existing key
            replace_in_file "$file" "^[#\\s]*${key}\s*=.*" "${key}=${value}" false
        else
            # Add a new key
            printf '\n%s=%s' "$key" "$value" >>"$file"
        fi
    fi
}

# 更新 server.properties 配置文件中指定变量值
# 全局变量:
#   APP_CONF_DIR
# 变量:
#   $1 - 变量
#   $2 - 值（列表）
kafka_server_conf_set() {
    kafka_common_conf_set "$APP_CONF_DIR/server.properties" "$@"
}

# 更新 producer.properties 及 consumer.properties 配置文件中指定变量值
# 全局变量:
#   APP_CONF_DIR
# 变量:
#   $1 - 变量
#   $2 - 值（列表）
kafka_producer_consumer_conf_set() {
    kafka_common_conf_set "$APP_CONF_DIR/producer.properties" "$@"
    kafka_common_conf_set "$APP_CONF_DIR/consumer.properties" "$@"
}

# 加载应用使用的环境变量初始值，该函数在相关脚本中以eval方式调用
# 全局变量:
#   KAFKA_*
# 返回值:
#   可以被 'eval' 使用的序列化输出
docker_app_env() {
	# 以下变量已经存在
	# APP_NAME、APP_EXEC、APP_USER、APP_GROUP、APP_VERSION
	# APP_BASE_DIR、APP_DEF_DIR、APP_CONF_DIR、APP_CERT_DIR、APP_DATA_DIR、APP_CACHE_DIR、APP_RUN_DIR、APP_LOG_DIR
    cat <<"EOF"
export KAFKA_ALLOW_PLAINTEXT_LISTENER="${KAFKA_ALLOW_PLAINTEXT_LISTENER:-no}"
export KAFKA_INTER_BROKER_USER="${KAFKA_INTER_BROKER_USER:-user}"
export KAFKA_INTER_BROKER_PASSWORD="${KAFKA_INTER_BROKER_PASSWORD:-colovu}"
export KAFKA_BROKER_USER="${KAFKA_BROKER_USER:-user}"
export KAFKA_BROKER_PASSWORD="${KAFKA_BROKER_PASSWORD:-colovu}"
export KAFKA_HEAP_OPTS="${KAFKA_HEAP_OPTS:-"-Xmx1024m -Xms1024m"}"
export KAFKA_ZOOKEEPER_PASSWORD="${KAFKA_ZOOKEEPER_PASSWORD:-}"
export KAFKA_ZOOKEEPER_USER="${KAFKA_ZOOKEEPER_USER:-}"
export KAFKA_PORT="${KAFKA_PORT:-9092}"

export KAFKA_CFG_BROKER_ID="${KAFKA_CFG_BROKER_ID}:-0"
export KAFKA_CFG_LISTENERS="${KAFKA_CFG_LISTENERS:-"PLAINTEXT://:${KAFKA_PORT:-9092}"}"
export KAFKA_CFG_ADVERTISED_LISTENERS="${KAFKA_CFG_ADVERTISED_LISTENERS:-"PLAINTEXT://:${KAFKA_PORT:-9092}"}"
export KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP="${KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP}:-"PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSLNUM_NETWORK_THREADS"
export KAFKA_CFG_NUM_NETWORK_THREADS="${KAFKA_CFG_NUM_NETWORK_THREADS}:-3"
export KAFKA_CFG_NUM_IO_THREADS="${KAFKA_CFG_NUM_IO_THREADS}:-8"
export KAFKA_CFG_SOCKET_SEND_BUFFER_BYTES="${KAFKA_CFG_SOCKET_SEND_BUFFER_BYTES}:-102400"
export KAFKA_CFG_SOCKET_RECEIVE_BUFFER_BYTES="${KAFKA_CFG_SOCKET_RECEIVE_BUFFER_BYTES}:-102400"
export KAFKA_CFG_SOCKET_REQUEST_MAX_BYTES="${KAFKA_CFG_SOCKET_REQUEST_MAX_BYTES}:-104857600"
export KAFKA_CFG_LOG_DIRS="${KAFKA_CFG_LOG_DIRS:-${APP_LOG_DIR}}"
export KAFKA_CFG_NUM_PARTITIONS="${KAFKA_CFG_NUM_PARTITIONS}:-1"
export KAFKA_CFG_NUM_RECOVERY_THREADS_PER_DATA_DIR="${KAFKA_CFG_NUM_RECOVERY_THREADS_PER_DATA_DIR}:-1"
export KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR="${KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR}:-1"
export KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR="${KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR}:-1"
export KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR="${KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR}:-1"
export KAFKA_CFG_LOG_FLUSH_INTERVAL_MESSAGES="${KAFKA_CFG_LOG_FLUSH_INTERVAL_MESSAGES}:-10000"
export KAFKA_CFG_LOG_FLUSH_INTERVAL_MS="${KAFKA_CFG_LOG_FLUSH_INTERVAL_MS}:-1000"
export KAFKA_CFG_LOG_RETENTION_HOURS="${KAFKA_CFG_LOG_RETENTION_HOURS}:-168"
export KAFKA_CFG_LOG_RETENTION_BYTES="${KAFKA_CFG_LOG_RETENTION_BYTES}:-1073741824"
export KAFKA_CFG_LOG_SEGMENT_BYTES="${KAFKA_CFG_LOG_SEGMENT_BYTES}:-1073741824"
export KAFKA_CFG_LOG_RETENTION_CHECK_INTERVAL_MS="${KAFKA_CFG_LOG_RETENTION_CHECK_INTERVAL_MS}:-300000"
export KAFKA_CFG_ZOOKEEPER_CONNECT="${KAFKA_CFG_ZOOKEEPER_CONNECT:-"localhost:2181"}"
export KAFKA_CFG_ZOOKEEPER_CONNECTION_TIMEOUT_MS="${KAFKA_CFG_ZOOKEEPER_CONNECTION_TIMEOUT_MS:-"6000"}"
export KAFKA_CFG_GROUP_INITIAL_REBALANCE_DELAY_MS="${KAFKA_CFG_GROUP_INITIAL_REBALANCE_DELAY_MS}:-0"
export KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE="${KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE:-"true"}"
EOF
}

# 检测用户参数信息是否满足条件
# 针对部分权限过于开放情况，可打印提示信息
app_verify_minimum_env() {
#	if [ "${#POSTGRES_PASSWORD}" -ge 100 ]; then
#		cat >&2 <<-'EOWARN'
#			WARNING: The supplied POSTGRES_PASSWORD is 100+ characters.
#			  This will not work if used via PGPASSWORD with "psql".
#			  https://www.postgresql.org/message-id/flat/E1Rqxp2-0004Qt-PL%40wrigleys.postgresql.org (BUG #6412)
#			  https://github.com/docker-library/postgres/issues/507
#		EOWARN
#	fi
#	if [ -z "$POSTGRES_PASSWORD" ] && [ 'trust' != "$POSTGRES_HOST_AUTH_METHOD" ]; then
#		# The - option suppresses leading tabs but *not* spaces. :)
#		cat >&2 <<-'EOE'
#			Error: Database is uninitialized and superuser password is not specified.
#			       You must specify POSTGRES_PASSWORD to a non-empty value for the
#			       superuser. For example, "-e POSTGRES_PASSWORD=password" on "docker run".
#			       You may also use "POSTGRES_HOST_AUTH_METHOD=trust" to allow all
#			       connections without a password. This is *not* recommended.
#			       See PostgreSQL documentation about "trust":
#			       https://www.postgresql.org/docs/current/auth-trust.html
#		EOE
#		exit 1
#	fi
	：
}

# 使用环境变量中的配置值更新配置文件
# 全局变量:
#   KAFKA_*
kafka_configure_from_environment_variables() {
    # Map environment variables to config properties
    for var in "${!KAFKA_CFG_@}"; do
        key="$(echo "$var" | sed -e 's/^KAFKA_CFG_//g' -e 's/_/\./g' | tr '[:upper:]' '[:lower:]')"
        value="${!var}"
        kafka_server_conf_set "$key" "$value"
    done
}

# 加载在后续脚本命令中使用的参数信息，包括从"*_FILE"文件中导入的配置
# 必须在其他函数使用前调用
docker_setup_env() {
	# 尝试从文件获取环境变量的值
	# file_env 'ENV_VAR_NAME'

	# 尝试从文件获取环境变量的值，如果不存在，使用默认值 default_val 
	# file_env 'ENV_VAR_NAME' 'default_val'

	# 检测变量 ENV_VAR_NAME 未定义或值为空，赋值为默认值：default_val
	# : "${ENV_VAR_NAME:=default_val}"

	declare -g DATABASE_ALREADY_EXISTS
	# 检测初始化是否已完成
	if [ -f "/srv/data/init_flag" ]; then
		DATABASE_ALREADY_EXISTS='true'
	fi
}

docker_app_init() {
	LOG_I "Initializing Kafka..."
	app_verify_minimum_env

    # DEPRECATED. Copy files in old conf directory to maintain compatibility with Helm chart.
    if ! is_dir_empty "$KAFKA_BASE_DIR"/conf; then
        LOG_W "Detected files mounted to $KAFKA_BASE_DIR/conf. This is deprecated and files should be mounted to $KAFKA_MOUNTED_CONF_DIR."
        cp -Lr "$KAFKA_BASE_DIR"/conf/* "$KAFKA_CONF_DIR"
    fi
    # Check for mounted configuration files
    if ! is_dir_empty "$KAFKA_MOUNTED_CONF_DIR"; then
        cp -Lr "$KAFKA_MOUNTED_CONF_DIR"/* "$KAFKA_CONF_DIR"
    fi
    # DEPRECATED. Check for server.properties file in old conf directory to maintain compatibility with Helm chart.
    if [[ ! -f "$KAFKA_BASE_DIR"/conf/server.properties ]] && [[ ! -f "$KAFKA_MOUNTED_CONF_DIR"/server.properties ]]; then
        LOG_I "No injected configuration files found, creating default config files"
        kafka_server_conf_set log.dirs "$KAFKA_DATA_DIR"
        kafka_configure_from_environment_variables
        if [[ "${KAFKA_CFG_LISTENERS:-}" =~ SASL_SSL ]] || [[ "${KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP:-}" =~ SASL_SSL ]]; then
            kafka_configure_sasl_ssl_listener
        elif [[ "${KAFKA_CFG_LISTENERS:-}" =~ SSL ]] || [[ "${KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP:-}" =~ SSL ]]; then
            kafka_configure_only_ssl_listener
        elif [[ "${KAFKA_CFG_LISTENERS:-}" =~ SASL_PLAINTEXT ]] || [[ "${KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP:-}" =~ SASL_PLAINTEXT ]]; then
            kafka_configure_sasl_plaintext_listener
        fi

        # Remove security.inter.broker.protocol if KAFKA_CFG_INTER_BROKER_LISTENER_NAME is configured
        if [[ ! -z "${KAFKA_CFG_INTER_BROKER_LISTENER_NAME:-}" ]]; then
            remove_in_file "$KAFKA_CONF_FILE" "security.inter.broker.protocol" false
        fi
    fi
}

# 应用初始化操作，包括执行目录initdb.d目录中的初始化脚本
docker_app_custom_init() {
	
		# 检测数据库存储目录是否为空；如果为空，进行初始化操作
		if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
		LOG_I "Process custom init scripts for Kafka..."

			# 检测目录权限，防止初始化失败
			ls /srv/conf/${APP_NAME}/initdb.d/ > /dev/null

			docker_process_init_files /srv/conf/${APP_NAME}/initdb.d/*

			echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." > /srv/data/init_flag

			LOG_I "Container for ${APP_NAME} init process complete; ready for start up."
		else
			LOG_I "Container for ${APP_NAME} already inited. Skipping initialization."
		fi
}
