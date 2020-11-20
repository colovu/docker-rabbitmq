#!/bin/bash
# Ver: 1.0 by Endial Fang (endial@126.com)
# 
# 应用通用业务处理函数

# 加载依赖脚本
. /usr/local/scripts/libcommon.sh       # 通用函数库

. /usr/local/scripts/libfile.sh
. /usr/local/scripts/libfs.sh
. /usr/local/scripts/libos.sh
. /usr/local/scripts/libservice.sh
. /usr/local/scripts/libvalidations.sh

# 函数列表

# 加载应用使用的环境变量初始值，该函数在相关脚本中以 eval 方式调用
# 全局变量:
#   ENV_* : 容器使用的全局变量
#   APP_* : 在镜像创建时定义的全局变量
#   *_* : 应用配置文件使用的全局变量，变量名根据配置项定义
# 返回值:
#   可以被 'eval' 使用的序列化输出
app_env() {
    cat <<-'EOF'
		# Common Settings
		export ENV_DEBUG=${ENV_DEBUG:-false}

		# Paths
		export RABBITMQ_HOME="${APP_HOME_DIR}"
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
		export RABBITMQ_COOKIE_FILE="${RABBITMQ_HOME_DIR}/.erlang.cookie"
		export RABBITMQ_PID_FILE="${APP_RUN_DIR}/rabbitmq.pid"

		# RabbitMQ locations
		export RABBITMQ_MNESIA_BASE="${RABBITMQ_DATA_DIR}"

		# Users

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
		export RABBITMQ_SSL_CERT_FILE="${RABBITMQ_SSL_CERT_FILE:-}"
		export RABBITMQ_SSL_KEY_FILE="${RABBITMQ_SSL_KEY_FILE:-}"
		export RABBITMQ_SSL_CA_FILE="${RABBITMQ_SSL_CA_FILE:-}"

		# Log, print all log messages to standard output by default
		export RABBITMQ_LOGS="${RABBITMQ_LOGS:--}"

		# Authentication
		export RABBITMQ_USERNAME="${RABBITMQ_USERNAME:-colovu}"
		export RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD:-pass4colovu}"
		export RABBITMQ_HASHED_PASSWORD="${RABBITMQ_HASHED_PASSWORD:-}"
EOF
}


# 生成 RabbitMQ 配置文件
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
      {default_permissions, [<<".*">>, <<".*">>, <<".*">>]},
      {loopback_users,[none]},
      {rabbit, [{log_levels, [{connection, warning}]}]}
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
HOME=${RABBITMQ_HOME_DIR}
NODE_PORT=${RABBITMQ_NODE_PORT_NUMBER}
NODENAME=${RABBITMQ_NODE_NAME}
#HOSTNAME=
RABBITMQ_LOGS=${RABBITMQ_LOG_DIR}/${RABBITMQ_NODE_NAME}.log
#RABBITMQ_PID_FILE=${APP_LOG_DIR}/${RABBITMQ_NODE_NAME}.pid
#RABBITMQ_NODE_PORT=${RABBITMQ_NODE_PORT_NUMBER}
#RABBITMQ_NODENAME=${RABBITMQ_NODE_NAME}
RABBITMQ_CONFIG_FILE=${RABBITMQ_CONFIG_FILE}
RABBITMQ_MNESIA_BASE=${RABBITMQ_DATA_DIR}
RABBITMQ_LOG_BASE=${RABBITMQ_LOG_DIR}
RABBITMQ_PLUGINS_DIR=${RABBITMQ_BASE_DIR}/plugins
RABBITMQ_ENABLED_PLUGINS_FILE=${RABBITMQ_CONF_DIR}/enabled_plugins
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
# Arguments:
#   $1 - Plugin to enable
rabbitmq_enable_plugin() {
    local plugin="${1:?plugin is required}"
    LOG_D "Enabling plugin '${plugin}'..."

    if ! debug_execute "rabbitmq-plugins" "enable" "--offline" "$plugin"; then
        LOG_W "Couldn't enable plugin '${plugin}'."
    fi
}


# 检测 RabbitMQ 节点是否在运行状态
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

# 更改 RabbitMQ 用户密码
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
# 参数:
#   $1 - 集群节点名
#   $2 - 节点类型
rabbitmq_join_cluster() {
    local clusternode="${1:?node is required}"
    local type="${2:?type is required}"

    local join_cluster_args=("$clusternode")
    [[ "$type" = "queue-ram" ]] && join_cluster_args+=("--ram")

    debug_execute "rabbitmqctl" stop_app
    debug_execute "rabbitmqctl" force_reset
    #debug_execute "rabbitmqctl" -n "${clusternode}" --offline forget_cluster_node "${RABBITMQ_NODE_NAME}"
    # rm -rf ${RABBITMQ_DATA_DIR}

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

# 检测用户参数信息是否满足条件; 针对部分权限过于开放情况，打印提示信息
app_verify_minimum_env() {
    local error_code=0
	
    LOG_D "Validating settings in RABBITMQ_* env vars..."

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
        ! is_root && validate_port_args+=("-unprivileged")
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

# 更改默认监听地址为 "*" 或 "0.0.0.0"，以对容器外提供服务；默认配置文件应当为仅监听 localhost(127.0.0.1)
app_enable_remote_connections() {
    LOG_D "Modify default config to enable all IP access"
	
}

# 检测依赖的服务端口是否就绪；该脚本依赖系统工具 'netcat'
# 参数:
#   $1 - host:port
app_wait_service() {
    local serviceport=${1:?Missing server info}
    local service=${serviceport%%:*}
    local port=${serviceport#*:}
    local retry_seconds=5
    local max_try=100
    let i=1

    if [[ -z "$(which nc)" ]]; then
        LOG_E "Nedd nc installed before, command: \"apt-get install netcat\"."
        exit 1
    fi

    LOG_I "[0/${max_try}] check for ${service}:${port}..."

    set +e
    nc -z ${service} ${port}
    result=$?

    until [ $result -eq 0 ]; do
      LOG_D "  [$i/${max_try}] not available yet"
      if (( $i == ${max_try} )); then
        LOG_E "${service}:${port} is still not available; giving up after ${max_try} tries."
        exit 1
      fi
      
      LOG_I "[$i/${max_try}] try in ${retry_seconds}s once again ..."
      let "i++"
      sleep ${retry_seconds}

      nc -z ${service} ${port}
      result=$?
    done

    set -e
    LOG_I "[$i/${max_try}] ${service}:${port} is available."
}

# 以后台方式启动应用服务，并等待启动就绪
app_start_server_bg() {
    is_app_server_running && return
    LOG_I "Starting ${APP_NAME} in background..."

    local start_command=()
    if is_root ; then
        start_command+=( gosu ${APP_USER} )
    fi
    start_command+=( rabbitmq-server )
    debug_execute "${start_command}" &

    #export RABBITMQ_PID="$!"

	# 通过命令或特定端口检测应用是否就绪
    LOG_I "Checking ${APP_NAME} ready status..."
    local start_check=()
    if is_root ; then
        start_check+=( gosu ${APP_USER} )
    fi

    # rabbitmqctl wait 命令需要系统安装 procps 软件包
    start_check+=( rabbitmqctl )
    local counter=0
    while ! debug_execute "${start_check}" wait "${RABBITMQ_PID_FILE}" --timeout 5; do
        LOG_D "Waiting for ${APP_NAME} to start..."
        counter=$((counter + 1))
        if [[ $counter -eq 10 ]]; then
            LOG_E "Couldn't start ${APP_NAME} in background."
            exit 1
        fi
    done

    LOG_D "${APP_NAME} is ready for service..."
}

# 停止应用服务
app_stop_server() {
    is_app_server_running || return
    LOG_I "Stopping ${APP_NAME}..."

    local start_command=()
    start_command+=( rabbitmqctl )
    debug_execute "${start_command}" stop

    local counter=10
    while [[ "$counter" -ne 0 ]] && is_app_server_running; do
        LOG_D "Waiting for ${APP_NAME} to stop..."
        sleep 1
        counter=$((counter - 1))
        rm -rf ${RABBITMQ_PID_FILE} || :
    done
}

# 检测应用服务是否在后台运行中
is_app_server_running() {
    LOG_D "Check if ${APP_NAME} is running..."
    local pid
    pid="$(get_pid_from_file ${RABBITMQ_PID_FILE})"

    if [[ -z "${pid}" ]]; then
        false
    else
        is_service_running "${pid}"
    fi
}

# 清理初始化应用时生成的临时文件
app_clean_tmp_file() {
    LOG_D "Clean ${APP_NAME} tmp files for init..."

}

# 在重新启动容器时，删除标志文件及必须删除的临时文件 (容器重新启动)
app_clean_from_restart() {
    LOG_D "Clean ${APP_NAME} tmp files for restart..."
    local -r -a files=(
        "${RABBITMQ_PID_FILE}"
    )

    for file in ${files[@]}; do
        if [[ -f "$file" ]]; then
            LOG_I "Cleaning stale $file file"
            rm "$file"
        fi
    done
}

# 应用默认初始化操作
# 执行完毕后，生成文件 ${APP_CONF_DIR}/.app_init_flag 及 ${APP_DATA_DIR}/.data_init_flag 文件
app_default_init() {
	app_clean_from_restart
    LOG_D "Check init status of ${APP_NAME}..."

    if [[ "${RABBITMQ_NODE_TYPE}" != "stats" ]] && [[ -n "${RABBITMQ_CLUSTER_NODE_NAME}" ]]; then
        if [[ "${RABBITMQ_CLUSTER_NODE_NAME}" = "${RABBITMQ_NODE_NAME}" ]]; then
            LOG_W "Current node work as master, skipping join cluster"
        else
            rm -rf "${RABBITMQ_HOME_DIR}/*"
            rm -rf "${RABBITMQ_DATA_DIR}/*"
            mkdir -p "${RABBITMQ_HOME_DIR}"
            debug_execute "rabbitmqctl" -n "${clusternode}" --offline forget_cluster_node "${RABBITMQ_NODE_NAME}" || :
        fi
    fi

    # 检测配置文件是否存在
    if [[ ! -f "${APP_CONF_DIR}/.app_init_flag" ]]; then
        LOG_I "No injected configuration file found, creating default config files..."
		
        [[ ! -f "${RABBITMQ_CONFIG_FILE}" ]] && rabbitmq_create_config_file
        [[ ! -f "${RABBITMQ_CONF_ENV_FILE}" ]] && rabbitmq_create_environment_file

        [[ ! -f "${RABBITMQ_COOKIE_FILE}" ]] && rabbitmq_create_erlang_cookie
        chmod 400 "${RABBITMQ_COOKIE_FILE}"
        ln -sf "${RABBITMQ_COOKIE_FILE}" "${RABBITMQ_LIB_DIR}/.erlang.cookie"

        touch ${APP_CONF_DIR}/.app_init_flag
        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> ${APP_CONF_DIR}/.app_init_flag
    else
        LOG_I "User injected custom configuration detected!"
    fi

    if [[ ! -f "${APP_DATA_DIR}/.data_init_flag" ]]; then
        LOG_I "Deploying ${APP_NAME} from scratch..."

		# 检测服务是否运行中如果未运行，则启动后台服务
        is_app_server_running || app_start_server_bg

        rabbitmq_change_password "$RABBITMQ_USERNAME" "$RABBITMQ_PASSWORD"

        if [[ "${RABBITMQ_NODE_TYPE}" != "stats" ]] && [[ -n "${RABBITMQ_CLUSTER_NODE_NAME}" ]]; then
            if [[ "${RABBITMQ_CLUSTER_NODE_NAME}" = "${RABBITMQ_NODE_NAME}" ]]; then
                LOG_W "Current node work as master, skipping join cluster"
            else
                rabbitmq_join_cluster "${RABBITMQ_CLUSTER_NODE_NAME}" "${RABBITMQ_NODE_TYPE}"
            fi
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

        touch ${APP_DATA_DIR}/.data_init_flag
        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> ${APP_DATA_DIR}/.data_init_flag
    else
        LOG_I "Deploying ${APP_NAME} with persisted data..."
    fi

}

# 用户自定义的前置初始化操作，依次执行目录 preinitdb.d 中的初始化脚本
# 执行完毕后，生成文件 ${APP_DATA_DIR}/.custom_preinit_flag
app_custom_preinit() {
    LOG_D "Check custom pre-init status of ${APP_NAME}..."

    # 检测用户配置文件目录是否存在 preinitdb.d 文件夹，如果存在，尝试执行目录中的初始化脚本
    if [ -d "/srv/conf/${APP_NAME}/preinitdb.d" ]; then
        # 检测数据存储目录是否存在已初始化标志文件；如果不存在，检索可执行脚本文件并进行初始化操作
        if [[ -n $(find "/srv/conf/${APP_NAME}/preinitdb.d/" -type f -regex ".*\.\(sh\)") ]] && \
            [[ ! -f "${APP_DATA_DIR}/.custom_preinit_flag" ]]; then
            LOG_I "Process custom pre-init scripts from /srv/conf/${APP_NAME}/preinitdb.d..."

            # 检索所有可执行脚本，排序后执行
            find "/srv/conf/${APP_NAME}/preinitdb.d/" -type f -regex ".*\.\(sh\)" | sort | process_init_files

            touch ${APP_DATA_DIR}/.custom_preinit_flag
            echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> ${APP_DATA_DIR}/.custom_preinit_flag
            LOG_I "Custom preinit for ${APP_NAME} complete."
        else
            LOG_I "Custom preinit for ${APP_NAME} already done before, skipping initialization."
        fi
    fi
}

# 用户自定义的应用初始化操作，依次执行目录initdb.d中的初始化脚本
# 执行完毕后，生成文件 ${APP_DATA_DIR}/.custom_init_flag
app_custom_init() {
    LOG_D "Check custom init status of ${APP_NAME}..."

    # 检测用户配置文件目录是否存在 initdb.d 文件夹，如果存在，尝试执行目录中的初始化脚本
    if [ -d "/srv/conf/${APP_NAME}/initdb.d" ]; then
    	# 检测数据存储目录是否存在已初始化标志文件；如果不存在，检索可执行脚本文件并进行初始化操作
    	if [[ -n $(find "/srv/conf/${APP_NAME}/initdb.d/" -type f -regex ".*\.\(sh\|sql\|sql.gz\)") ]] && \
            [[ ! -f "${APP_DATA_DIR}/.custom_init_flag" ]]; then
            LOG_I "Process custom init scripts from /srv/conf/${APP_NAME}/initdb.d..."

            # 检测服务是否运行中；如果未运行，则启动后台服务
            is_app_server_running || app_start_server_bg

            # 检索所有可执行脚本，排序后执行
    		find "/srv/conf/${APP_NAME}/initdb.d/" -type f -regex ".*\.\(sh\|sql\|sql.gz\)" | sort | while read -r f; do
                case "$f" in
                    *.sh)
                        if [[ -x "$f" ]]; then
                            LOG_D "Executing $f"; "$f"
                        else
                            LOG_D "Sourcing $f"; . "$f"
                        fi
                        ;;
                    #*.sql)    LOG_D "Executing $f"; postgresql_execute "$PG_DATABASE" "$PG_INITSCRIPTS_USERNAME" "$PG_INITSCRIPTS_PASSWORD" < "$f";;
                    #*.sql.gz) LOG_D "Executing $f"; gunzip -c "$f" | postgresql_execute "$PG_DATABASE" "$PG_INITSCRIPTS_USERNAME" "$PG_INITSCRIPTS_PASSWORD";;
                    *)        LOG_D "Ignoring $f" ;;
                esac
            done

            touch ${APP_DATA_DIR}/.custom_init_flag
    		echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> ${APP_DATA_DIR}/.custom_init_flag
    		LOG_I "Custom init for ${APP_NAME} complete."
    	else
    		LOG_I "Custom init for ${APP_NAME} already done before, skipping initialization."
    	fi
    fi

    # 检测服务是否运行中；如果运行，则停止后台服务
	is_app_server_running && app_stop_server

    # 删除第一次运行生成的临时文件
    app_clean_tmp_file

	# 绑定所有 IP ，启用远程访问
    app_enable_remote_connections
}
