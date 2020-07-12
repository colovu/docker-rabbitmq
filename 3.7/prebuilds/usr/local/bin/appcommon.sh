#!/bin/bash
#
# 应用通用业务处理函数

# 加载依赖脚本
. /usr/local/scripts/liblog.sh
. /usr/local/scripts/libfile.sh
. /usr/local/scripts/libfs.sh
. /usr/local/scripts/libos.sh
. /usr/local/scripts/libcommon.sh
. /usr/local/scripts/libvalidations.sh
. /usr/local/scripts/libservice.sh

# 函数列表

# 加载应用使用的环境变量初始值，该函数在相关脚本中以eval方式调用
# 全局变量:
#   ENV_* : 容器使用的全局变量
#   RABBITMQ_* : 应用配置文件使用的全局变量，变量名根据配置项定义
# 返回值:
#   可以被 'eval' 使用的序列化输出
docker_app_env() {
    # 以下变量已经在创建镜像时定义，可直接使用
    # APP_NAME、APP_EXEC、APP_USER、APP_GROUP、APP_VERSION
    # APP_BASE_DIR、APP_DEF_DIR、APP_CONF_DIR、APP_CERT_DIR、APP_DATA_DIR、APP_CACHE_DIR、APP_RUN_DIR、APP_LOG_DIR
    cat <<"EOF"
# Debug log message
export ENV_DEBUG=${ENV_DEBUG:-false}

# Paths
export RABBITMQ_BASE_DIR="${RABBITMQ_BASE_DIR:-${APP_HOME_DIR}}"
export RABBITMQ_CONF_DIR="${RABBITMQ_CONF_DIR:-${APP_CONF_DIR}}"
export RABBITMQ_DATA_DIR="${RABBITMQ_DATA_DIR:-${APP_DATA_DIR}/mnesia}"
export RABBITMQ_LOG_DIR="${RABBITMQ_LOG_DIR:-${APP_LOG_DIR}}"
export RABBITMQ_HOME_DIR="${APP_DATA_DIR}/.rabbitmq"
export RABBITMQ_LIB_DIR="${RABBITMQ_BASE_DIR}/var/lib/rabbitmq"
export RABBITMQ_PLUGINS_DIR="${RABBITMQ_BASE_DIR}/plugins"
export RABBITMQ_BIN_DIR="${RABBITMQ_BASE_DIR}/sbin"

export RABBITMQ_CONFIG_FILE="${RABBITMQ_CONF_DIR}/rabbitmq.config"
export RABBITMQ_ADVANCED_CONFIG_FILE="${RABBITMQ_CONF_DIR}/advanced.config"
export RABBITMQ_CONF_ENV_FILE="${RABBITMQ_CONF_DIR}/rabbit-env.conf"
export RABBITMQ_COOKIE_FILE="${APP_DATA_DIR}/.erlang.cookie"

# RabbitMQ locations
export RABBITMQ_MNESIA_BASE="${RABBITMQ_DATA_DIR}"

# Users
export RABBITMQ_DAEMON_USER="${RABBITMQ_DAEMON_USER:-${APP_USER}}"
export RABBITMQ_DAEMON_GROUP="${RABBITMQ_DAEMON_GROUP:-${APP_GROUP}}"

# Cluster configuration
export RABBITMQ_CLUSTER_NODE_NAME="${RABBITMQ_CLUSTER_NODE_NAME:-}"
export RABBITMQ_CLUSTER_PARTITION_HANDLING="${RABBITMQ_CLUSTER_PARTITION_HANDLING:-ignore}"
export RABBITMQ_ERL_COOKIE="${RABBITMQ_ERL_COOKIE:-}"

# RabbitMQ settings
export RABBITMQ_DISK_FREE_LIMIT="${RABBITMQ_DISK_FREE_LIMIT:-{mem_relative, 1.0\}}"
export RABBITMQ_MANAGER_BIND_IP="${RABBITMQ_MANAGER_BIND_IP:-0.0.0.0}"
export RABBITMQ_MANAGER_PORT_NUMBER="${RABBITMQ_MANAGER_PORT_NUMBER:-15672}"
export RABBITMQ_NODE_NAME="${RABBITMQ_NODE_NAME:-rabbit@localhost}"
export RABBITMQ_NODE_PORT_NUMBER="${RABBITMQ_NODE_PORT_NUMBER:-5672}"
export RABBITMQ_NODE_TYPE="${RABBITMQ_NODE_TYPE:-stats}"
export RABBITMQ_VHOST="${RABBITMQ_VHOST:-/}"
export RABBITMQ_ENABLE_PLUGINS="${RABBITMQ_ENABLE_PLUGINS:-}"

# STOMP Plug-ins Settings
export RABBITMQ_STOMP_USERNAME="${RABBITMQ_STOMP_USERNAME:-admin}"
export RABBITMQ_STOMP_PASSWORD="${RABBITMQ_STOMP_PASSWORD:-colovu}"
export RABBITMQ_STOMP_VHOST="${RABBITMQ_STOMP_VHOST:-${RABBITMQ_VHOST}}"
export RABBITMQ_STOMP_PORT_NUMBER="${RABBITMQ_STOMP_PORT_NUMBER:-61613}"

# LDAP Settings
export RABBITMQ_ENABLE_LDAP="${RABBITMQ_ENABLE_LDAP:-no}"
export RABBITMQ_LDAP_TLS="${RABBITMQ_LDAP_TLS:-no}"
export RABBITMQ_LDAP_SERVER="${RABBITMQ_LDAP_SERVER:-}"
export RABBITMQ_LDAP_SERVER_PORT="${RABBITMQ_LDAP_SERVER_PORT:-389}"
export RABBITMQ_LDAP_USER_DN_PATTERN="${RABBITMQ_LDAP_USER_DN_PATTERN:-}"
export RABBITMQ_SSL_CERT_FILE="${RABBITMQ_SSL_CERT_FILE:-}}"
export RABBITMQ_SSL_KEY_FILE="${RABBITMQ_SSL_KEY_FILE:-}}"
export RABBITMQ_SSL_CA_FILE="${RABBITMQ_SSL_CA_FILE:-}}"

# Log, print all log messages to standard output by default
export RABBITMQ_LOGS="${RABBITMQ_LOGS:--}"

# Authentication
export RABBITMQ_USERNAME="${RABBITMQ_USERNAME:-colovu}"
export RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD:-pass4colovu}"
export RABBITMQ_HASHED_PASSWORD="${RABBITMQ_HASHED_PASSWORD:-}"
EOF
}

# 检测用户参数信息是否满足条件
# 针对部分权限过于开放情况，可打印提示信息
app_verify_minimum_env() {
    local error_code=0
    LOG_D "Validating settings in RABBITMQ_* env vars..."

    # Auxiliary functions
    print_validation_error() {
        LOG_E "$1"
        error_code=1
    }

    if [[ -z "$RABBITMQ_PASSWORD" && -z "$RABBITMQ_HASHED_PASSWORD" ]]; then
        print_validation_error "You must indicate a password or a hashed password."
    fi

    if [[ -n "$RABBITMQ_PASSWORD" && -n "$RABBITMQ_HASHED_PASSWORD" ]]; then
        LOG_W "You initialized RabbitMQ indicating both a password and a hashed password. Please note only the hashed password will be considered."
    fi

    if ! is_yes_no_value "$RABBITMQ_ENABLE_LDAP"; then
        print_validation_error "An invalid value was specified in the environment variable RABBITMQ_ENABLE_LDAP. Valid values are: yes or no"
    fi

    if is_boolean_yes "$RABBITMQ_ENABLE_LDAP" && ( [[ -z "${RABBITMQ_LDAP_SERVER}" ]] || [[ -z "${RABBITMQ_LDAP_USER_DN_PATTERN}" ]] ); then
        print_validation_error "The LDAP configuration is required when LDAP authentication is enabled. Set the environment variables RABBITMQ_LDAP_SERVER and RABBITMQ_LDAP_USER_DN_PATTERN."
        if !  is_yes_no_value "$RABBITMQ_LDAP_TLS"; then
            print_validation_error "An invalid value was specified in the environment variable RABBITMQ_LDAP_TLS. Valid values are: yes or no"
        fi
    fi

    if [[ "$RABBITMQ_NODE_TYPE" = "stats" ]]; then
        if ! validate_ipv4 "$RABBITMQ_MANAGER_BIND_IP"; then
            print_validation_error "An invalid IP was specified in the environment variable RABBITMQ_MANAGER_BIND_IP."
        fi

        local validate_port_args=()
        ! _is_run_as_root && validate_port_args+=("-unprivileged")
        if ! err=$(validate_port "${validate_port_args[@]}" "$RABBITMQ_MANAGER_PORT_NUMBER"); then
            print_validation_error "An invalid port was specified in the environment variable RABBITMQ_MANAGER_PORT_NUMBER: ${err}."
        fi

        if [[ -n "$RABBITMQ_CLUSTER_NODE_NAME" ]]; then
            LOG_W "This node will not be clustered. Use type queue-* instead."
        fi
    elif [[ "$RABBITMQ_NODE_TYPE" = "queue-disc" ]] || [[ "$RABBITMQ_NODE_TYPE" = "queue-ram" ]]; then
        if [[ -z "$RABBITMQ_CLUSTER_NODE_NAME" ]]; then
            LOG_W "You did not define any node to cluster with."
        fi
    else
        print_validation_error "${RABBITMQ_NODE_TYPE} is not a valid type. You can use 'stats', 'queue-disc' or 'queue-ram'."
    fi

    [[ "$error_code" -eq 0 ]] || exit "$error_code"
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
    : 
}

# 生成 RabbitMQ 配置文件
# 全局变量:
#   RABBITMQ_CONF_DIR
#   RABBITMQ_*
rabbitmq_create_config_file() {
    LOG_D "Creating configuration file..."
    local auth_backend=""
    local separator=""

    is_boolean_yes "$RABBITMQ_ENABLE_LDAP" && auth_backend="{auth_backends, [rabbit_auth_backend_ldap]},"
    is_boolean_yes "$RABBITMQ_LDAP_TLS" && separator=","

    # 配置基本参数
    cat > "${RABBITMQ_CONFIG_FILE}" <<EOF
[
  {rabbit,
    [
      $auth_backend
      {tcp_listeners, [$RABBITMQ_NODE_PORT_NUMBER]},
      {disk_free_limit, $RABBITMQ_DISK_FREE_LIMIT},
      {cluster_partition_handling, $RABBITMQ_CLUSTER_PARTITION_HANDLING},
      {default_vhost, <<"$RABBITMQ_VHOST">>},
      {default_user, <<"$RABBITMQ_USERNAME">>},
      {default_permissions, [<<".*">>, <<".*">>, <<".*">>]}
      {loopback_users,[none]}
EOF

    # 配置 LDAP 参数 
    if is_boolean_yes "$RABBITMQ_ENABLE_LDAP"; then
        cat >> "${RABBITMQ_CONFIG_FILE}" <<EOF
    ]
  },
  {rabbitmq_auth_backend_ldap,
    [
     {servers,               ["$RABBITMQ_LDAP_SERVER"]},
     {user_dn_pattern,       "$RABBITMQ_LDAP_USER_DN_PATTERN"},
     {port,                  $RABBITMQ_LDAP_SERVER_PORT}$separator
EOF

        if is_boolean_yes "$RABBITMQ_LDAP_TLS"; then
            cat >> "${RABBITMQ_CONFIG_FILE}" <<EOF
     {use_ssl,               true}
EOF
        fi
    fi

    # 配置 STOMP 插件参数
    #       {tcp_listeners, [{"0.0.0.0", ${RABBITMQ_STOMP_PORT_NUMBER}}, {"::1",${RABBITMQ_STOMP_PORT_NUMBER}}]},
    for plugs in ${RABBITMQ_ENABLE_PLUGINS}; do
        if [[ "$plugs" = "rabbitmq_stomp" ]]; then
            LOG_D "Set default parameter for plugin: $plugs"
            cat >> "${RABBITMQ_CONFIG_FILE}" <<EOF
    ]
  },
  {rabbitmq_stomp,
    [
      {default_user, [{login, "${RABBITMQ_STOMP_USERNAME}"}, {passcode, "${RABBITMQ_STOMP_PASSWORD}"}]},
      {tcp_listeners, [{"0.0.0.0", ${RABBITMQ_STOMP_PORT_NUMBER}}]},
      {default_vhost, <<"${RABBITMQ_STOMP_VHOST}">>}
EOF
        fi
    done  

    # 配置 management 插件参数
    cat >> "${RABBITMQ_CONFIG_FILE}" <<EOF
    ]
  },
  {rabbitmq_management,
    [
      {listener, [{port, $RABBITMQ_MANAGER_PORT_NUMBER}, {ip, "$RABBITMQ_MANAGER_BIND_IP"}]},
      {strict_transport_security, "max-age=0;"}
    ]
  }
].
EOF
}

# 生成 RabbitMQ 环境变量配置文件
# 全局变量:
#   RABBITMQ_CONF_DIR
# 变量列表参见：http://www.rabbitmq.com/configure.html#define-environment-variables
rabbitmq_create_environment_file() {
    LOG_D "Creating environment file..."
    cat > "${RABBITMQ_CONF_ENV_FILE}" <<EOF
HOME=$RABBITMQ_HOME_DIR
NODE_PORT=$RABBITMQ_NODE_PORT_NUMBER
NODENAME=$RABBITMQ_NODE_NAME
#HOSTNAME=
#RABBITMQ_NODENAME=mq
#RABBITMQ_NODE_PORT=
RABBITMQ_CONFIG_FILE=$RABBITMQ_CONFIG_FILE
RABBITMQ_MNESIA_BASE=$RABBITMQ_DATA_DIR
RABBITMQ_LOG_BASE=$RABBITMQ_LOG_DIR
#RABBITMQ_PLUGINS_DIR=/rabbitmq/plugins
EOF
}

# 生成 RabbitMQ Erlang cookie 文件
# 全局变量:
#   RABBITMQ_ERL_COOKIE
#   RABBITMQ_HOME_DIR
#   RABBITMQ_LIB_DIR
rabbitmq_create_erlang_cookie() {
    LOG_D "Creating Erlang cookie..."
    if [[ -z $RABBITMQ_ERL_COOKIE ]]; then
        LOG_I "Generating random cookie"
        RABBITMQ_ERL_COOKIE=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c32)
    fi

    echo "$RABBITMQ_ERL_COOKIE" > "${RABBITMQ_COOKIE_FILE}"
}

# 启用 RabbitMQ 插件
# 全局变量:
#   RABBITMQ_BIN_DIR
#   BITNAMI_DEBUG
# Arguments:
#   $1 - Plugin to enable
rabbitmq_enable_plugin() {
    local plugin="${1:?plugin is required}"
    LOG_D "Enabling plugin '${plugin}'..."

    if ! debug_execute "rabbitmq-plugins" "enable" "--offline" "$plugin"; then
        LOG_W "Couldn't enable plugin '${plugin}'."
    fi
}

# 检测 RabbitMQ 是否在运行中
# 全局变量:
#   RABBITMQ_PID
#   RABBITMQ_BIN_DIR
# 返回值:
#   Boolean
is_rabbitmq_running() {
    if [[ -z "${RABBITMQ_PID:-}" ]]; then
        false
    else
        is_service_running "$RABBITMQ_PID"
    fi
}

# 检测 RabbitMQ 节点是否在运行状态
# 全局变量:
#   RABBITMQ_BIN_DIR
# 参数:
#   $1 - Node to check
node_is_running() {
    local node="${1:?node is required}"
    LOG_I "Checking node ${node}"
    if debug_execute "rabbitmqctl" await_startup -n "$node"; then
        true
    else
        false
    fi
}

# 以后台方式启动 RabbitMQ 服务，并等待启动就绪
# 全局变量:
#   ENV_DEBUG
#   RABBITMQ_BIN_DIR
rabbitmq_start_bg() {
    is_rabbitmq_running && return
    LOG_I "Starting RabbitMQ in background..."
    if [[ "${ENV_DEBUG:-false}" = true ]]; then
        debug_execute "rabbitmq-server" &
    else
        debug_execute "rabbitmq-server" >/dev/null 2>&1 &
    fi
    export RABBITMQ_PID="$!"

    local counter=0
    while ! debug_execute "rabbitmqctl" wait --pid "$RABBITMQ_PID" --timeout 5; do
        LOG_D "Waiting for RabbitMQ to start..."
        counter=$((counter + 1))

        if [[ $counter -eq 10 ]]; then
            LOG_E "Couldn't start RabbitMQ in background."
            exit 1
        fi
    done
}

# 停止 RabbitMQ
# 全局变量:
#   ENV_DEBUG
#   RABBITMQ_BIN_DIR
rabbitmq_stop() {
    ! is_rabbitmq_running && return
    LOG_I "Stopping RabbitMQ..."

    debug_execute "rabbitmqctl" stop

    local counter=10
    while [[ "$counter" -ne 0 ]] && is_rabbitmq_running; do
        LOG_D "Waiting for RabbitMQ to stop..."
        sleep 1
        counter=$((counter - 1))
    done
}

# 更改 RabbitMQ 用户密码
# 全局变量:
#   ENV_DEBUG
#   RABBITMQ_BIN_DIR
# 参数:
#   $1 - 用户名
#   $2 - 用户新密码
rabbitmq_change_password() {
    local user="${1:?user is required}"
    local password="${2:?password is required}"
    LOG_D "Changing password for user '${user}'..."

    if ! debug_execute "rabbitmqctl" change_password "$user" "$password"; then
        LOG_E "Couldn't change password for user '${user}'."
        exit 1
    fi
}

# 将当前 RabbitMQ 节点加入指定集群
# 全局变量:
#   ENV_DEBUG
#   RABBITMQ_BIN_DIR
# 参数:
#   $1 - 集群节点名
#   $2 - 节点类型
rabbitmq_join_cluster() {
    local clusternode="${1:?node is required}"
    local type="${2:?type is required}"

    local join_cluster_args=("$clusternode")
    [[ "$type" = "queue-ram" ]] && join_cluster_args+=("--ram")

    debug_execute "rabbitmqctl" stop_app

    local counter=0
    while ! debug_execute "rabbitmq-plugins" --node "$clusternode" is_enabled rabbitmq_management; do
        LOG_D "Waiting for ${clusternode} to be ready..."
        counter=$((counter + 1))
        sleep 1
        if [[ $counter -eq 120 ]]; then
            LOG_E "Node ${clusternode} is not running."
            exit 1
        fi
    done

    LOG_I "Clustering with ${clusternode}"
    if ! debug_execute "rabbitmqctl" join_cluster "${join_cluster_args[@]}"; then
        LOG_E "Couldn't cluster with node '${clusternode}'."
        exit 1
    fi

    debug_execute "rabbitmqctl" start_app
}

# 应用默认初始化操作
# 执行完毕后，会在 ${RABBITMQ_DATA_DIR} 目录中生成 app_init_flag 及 data_init_flag 文件
docker_app_init() {
    LOG_D "Check init status of RabbitMQ..."

    # 检测配置文件是否存在
    if [[ ! -f "${RABBITMQ_CONF_DIR}/.app_init_flag" ]]; then
        LOG_I "No injected configuration file found, creating default config files..."
        [[ ! -f "${RABBITMQ_CONFIG_FILE}" ]] && rabbitmq_create_config_file
        [[ ! -f "${RABBITMQ_CONF_ENV_FILE}" ]] && rabbitmq_create_environment_file

        [[ ! -f "${RABBITMQ_COOKIE_FILE}" ]] && rabbitmq_create_erlang_cookie
        chmod 400 "${RABBITMQ_COOKIE_FILE}"
        ln -sf "${RABBITMQ_COOKIE_FILE}" "${RABBITMQ_LIB_DIR}/.erlang.cookie"

        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." > ${RABBITMQ_CONF_DIR}/.app_init_flag
    else
        LOG_I "User injected custom configuration detected!"
    fi

    if is_dir_empty "$RABBITMQ_DATA_DIR" || [[ ! -f "${APP_DATA_DIR}/.data_init_flag" ]]; then
        LOG_I "Deploying RabbitMQ from scratch..."

        ! is_rabbitmq_running && rabbitmq_start_bg

        rabbitmq_change_password "$RABBITMQ_USERNAME" "$RABBITMQ_PASSWORD"

        if [[ "$RABBITMQ_NODE_TYPE" != "stats" ]] && [[ -n "$RABBITMQ_CLUSTER_NODE_NAME" ]]; then
            rabbitmq_join_cluster "$RABBITMQ_CLUSTER_NODE_NAME" "$RABBITMQ_NODE_TYPE"
        fi

        LOG_I "Enable RabbitMQ Plugins..."
        if [[ "$RABBITMQ_NODE_TYPE" = "stats" ]]; then
            rabbitmq_enable_plugin "rabbitmq_management"
        else
            rabbitmq_enable_plugin "rabbitmq_management_agent"
        fi

        if is_boolean_yes "$RABBITMQ_ENABLE_LDAP"; then
            rabbitmq_enable_plugin "rabbitmq_auth_backend_ldap"
        fi

        if [[ ! -z "${RABBITMQ_ENABLE_PLUGINS}" ]]; then
            for plugs in ${RABBITMQ_ENABLE_PLUGINS}; do
                rabbitmq_enable_plugin "$plugs"
            done
        fi

        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." > ${APP_DATA_DIR}/.data_init_flag
    else
        LOG_I "Deploying RabbitMQ with persisted data..."
    fi

    is_rabbitmq_running && rabbitmq_stop
}

# 用户自定义的应用初始化操作，依次执行目录initdb.d中的初始化脚本
# 执行完毕后，会在 ${RABBITMQ_DATA_DIR} 目录中生成 .custom_init_flag 文件
docker_custom_init() {
    # 检测用户配置文件目录是否存在initdb.d文件夹，如果存在，尝试执行目录中的初始化脚本
    if [ -d "/srv/conf/${APP_NAME}/initdb.d" ]; then
    	# 检测数据存储目录是否存在已初始化标志文件；如果不存在，进行初始化操作
    	if [ ! -f "${RABBITMQ_DATA_DIR}/.custom_init_flag" ]; then
            LOG_I "Process custom init scripts for ${APP_NAME}..."

    		# 检测目录权限，防止初始化失败
    		ls "/srv/conf/${APP_NAME}/initdb.d/" > /dev/null

    		docker_process_init_files /srv/conf/${APP_NAME}/initdb.d/*

    		echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." > ${RABBITMQ_DATA_DIR}/.custom_init_flag
    		LOG_I "Custom init for ${APP_NAME} complete."
    	else
    		LOG_I "Custom init for ${APP_NAME} already done before, skipping initialization."
    	fi
    fi
}
