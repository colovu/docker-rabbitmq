# Ver: 1.2 by Endial Fang (endial@126.com)
#

# 预处理 =========================================================================
FROM colovu/dbuilder as builder

# sources.list 可使用版本：default / tencent / ustc / aliyun / huawei
ARG apt_source=default

# 编译镜像时指定用于加速的本地服务器地址
ARG local_url=""

ARG erlang_ver=22.3.2

ENV APP_NAME=rabbitmq \
	APP_VERSION=3.8.3

WORKDIR /usr/local

RUN select_source ${apt_source};
#RUN install_pkg xz-utils

# 下载并解压软件包
RUN set -eux; \
#	appVersion=1.12; \
	appName="${APP_NAME}-server-generic-unix-latest-toolchain-${APP_VERSION}.tar.xz"; \
	appKeys="0x0A9AF2115F4687BD29803A206B73A36E6026DFCA"; \
	[ ! -z ${local_url} ] && localURL=${local_url}/rabbitmq; \
	appUrls="${localURL:-} \
		https://github.com/rabbitmq/rabbitmq-server/releases/download/v${APP_VERSION} \
		"; \
	download_pkg unpack ${appName} "${appUrls}" -g "${appKeys}"; 

# 源码编译软件包
#RUN set -eux; \
# 源码编译方式安装: 编译后将原始配置文件拷贝至 ${APP_DEF_DIR} 中
#	mkdir -p /usr/local/${APP_NAME}; \
#	APP_SRC="/usr/local/${APP_NAME}-${APP_VERSION}"; \
#	cd ${APP_SRC}; \
#	./configure ; \
#	make -j "$(nproc)"; \
#	make PREFIX=/usr/local/${APP_NAME} install; \
#	cp -rf ./conf/* ${APP_DEF_DIR}/; 

# Alpine: scanelf --needed --nobanner --format '%n#p' --recursive /usr/local | tr ',' '\n' | sort -u | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }'
# Debian: find /usr/local/redis/bin -type f -executable -exec ldd '{}' ';' | awk '/=>/ { print $(NF-1) }' | sort -u | xargs -r dpkg-query --search | cut -d: -f1 | sort -u

# 镜像生成 ========================================================================
FROM colovu/debian:10

ARG apt_source=default
ARG local_url=""

ARG erlang_ver=22.3.2

ENV APP_NAME=rabbitmq \
	APP_USER=rabbitmq \
	APP_EXEC=rabbitmq-server \
	APP_VERSION=3.8.3

ENV	APP_HOME_DIR=/usr/local/${APP_NAME} \
	APP_DEF_DIR=/etc/${APP_NAME} \
	APP_CONF_DIR=/srv/conf/${APP_NAME} \
	APP_DATA_DIR=/srv/data/${APP_NAME} \
	APP_DATA_LOG_DIR=/srv/datalog/${APP_NAME} \
	APP_CACHE_DIR=/var/cache/${APP_NAME} \
	APP_RUN_DIR=/var/run/${APP_NAME} \
	APP_LOG_DIR=/var/log/${APP_NAME} \
	APP_CERT_DIR=/srv/cert/${APP_NAME}

ENV PATH="${APP_HOME_DIR}/sbin:${PATH}"

LABEL \
	"Version"="v${APP_VERSION}" \
	"Description"="Docker image for ${APP_NAME}(v${APP_VERSION})." \
	"Dockerfile"="https://github.com/colovu/docker-${APP_NAME}" \
	"Vendor"="Endial Fang (endial@126.com)"

COPY customer /

# 以包管理方式安装软件包(Optional)
RUN select_source ${apt_source}
RUN install_pkg procps

RUN create_user && prepare_env

# 从预处理过程中拷贝软件包(Optional)
#COPY --from=0 /usr/local/bin/ /usr/local/bin
COPY --from=builder /usr/local/rabbitmq_server-3.8.3/ /usr/local/rabbitmq
#COPY --from=builder /usr/local/redis/conf /etc/redis

# 编译安装 Openssl 及 Erlang
RUN export DEBIAN_FRONTEND=noninteractive; \
	set -eux; \
	\
# 为应用创建对应的组、用户、相关目录
	export OTP_VERSION=${erlang_ver}; \
	export OPENSSL_VERSION=1.1.1g; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
# 安装临时使用的软件包及依赖项。相关软件包在镜像创建完后时，会被清理
	fetchDeps=" \
		wget \
		ca-certificates \
		\
		autoconf \
		make \
		gcc \
		dpkg-dev \
		libncurses5-dev \
		\
		gnupg \
		dirmngr \
		xz-utils \
	"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ${fetchDeps}; \
	\
	\
	# 使用下载(编译)方式安装软件 OpenSSL
	DIST_NAME="openssl-${OPENSSL_VERSION}.tar.gz"; \
	DIST_SHA256="ddb04774f1e32f0c49751e21b67216ac87852ceb056b75209af2443400636d46"; \
	DIST_KEYID="0x8657ABB260F056B1E5190839D9C4D26D0E604491 \
		0x5B2545DAB21995F4088CEFAA36CEE4DEB00CFE33 \
		0xED230BEC4D4F2518B9D7DF41F0DB4D21C1D35231 \
		0xC1F33DD8CE1D4CC613AF14DA9195C48241FBF7DD \
		0x7953AC1FBC3DC8B3B292393ED5E9E43F7DF9EE8C \
		0xE5E52560DD91C556DDBDA5D02064C53641C25E5D"; \
	[ ! -z ${local_url} ] && localURL=${local_url}/openssl; \
	DIST_URLS="${localURL:-} \
		https://www.openssl.org/source \
		"; \
	download_pkg unpack ${DIST_NAME} "${DIST_URLS}" -s "${DIST_SHA256}"; \
	\
# 源码编译
	APP_SRC="/usr/local/openssl-${OPENSSL_VERSION}/"; \
	APP_CONFIG_DIR=/etc/ssl; \
	cd ${APP_SRC}; \
	debMultiarch="$(dpkg-architecture --query DEB_HOST_MULTIARCH)"; \
	MACHINE="$(dpkg-architecture --query DEB_BUILD_GNU_CPU)" \
	RELEASE="4.x.y-z" SYSTEM='Linux' BUILD='???' ./config \
		--openssldir="${APP_CONFIG_DIR}" \
		--libdir="lib/${debMultiarch}" \
		-Wl,-rpath=/usr/local/lib \
		; \
	make -j "$(nproc)"; \
	make install_sw install_ssldirs; \
	cd /; \
	rm -rf ${APP_SRC} /tmp/${DIST_NAME}; \
	ldconfig; \
	\
	\
	\
# 使用下载(编译)方式安装软件 ErLang
	DIST_NAME="OTP-${OTP_VERSION}.tar.gz"; \
	DIST_SHA256="4a3719c71a7998e4f57e73920439b4b1606f7c045e437a0f0f9f1613594d3eaa"; \
	[ ! -z ${local_url} ] && localURL=${local_url}/erlang; \
	DIST_URLS="${localURL:-} \
		https://github.com/erlang/otp/archive \
		"; \
	download_pkg unpack ${DIST_NAME} "${DIST_URLS}" -s "${DIST_SHA256}"; \
	\
# 源码编译
	APP_SRC="/usr/local/otp-OTP-${OTP_VERSION}"; \
	cd ${APP_SRC}; \
	export ERL_TOP="${APP_SRC}"; \
	./otp_build autoconf; \
	CFLAGS="$(dpkg-buildflags --get CFLAGS)"; export CFLAGS; \
	export CFLAGS="$CFLAGS -Wl,-rpath=/usr/local/lib"; \
	hostArch="$(dpkg-architecture --query DEB_HOST_GNU_TYPE)"; \
	buildArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	dpkgArch="$(dpkg --print-architecture)"; dpkgArch="${dpkgArch##*-}"; \
	./configure \
		--host="$hostArch" \
		--build="$buildArch" \
		--disable-dynamic-ssl-lib \
		--disable-hipe \
		--disable-sctp \
		--disable-silent-rules \
		--enable-clock-gettime \
		--enable-hybrid-heap \
		--enable-kernel-poll \
		--enable-shared-zlib \
		--enable-smp-support \
		--enable-threads \
		--with-microstate-accounting=extra \
		--without-common_test \
		--without-debugger \
		--without-dialyzer \
		--without-diameter \
		--without-edoc \
		--without-erl_docgen \
		--without-erl_interface \
		--without-et \
		--without-eunit \
		--without-ftp \
		--without-hipe \
		--without-jinterface \
		--without-megaco \
		--without-observer \
		--without-odbc \
		--without-reltool \
		--without-ssh \
		--without-tftp \
		--without-wx \
	; \
	make -j "$(nproc)" GEN_OPT_FLGS="-O2 -fno-strict-aliasing"; \
	make install; \
	cd /; \
	rm -rf ${APP_SRC} /tmp/${DIST_NAME} \
		/usr/local/lib/erlang/lib/*/examples \
		/usr/local/lib/erlang/lib/*/src \
		; \
	\
	\
	\
# 查找新安装的应用及应用依赖软件包，并标识为'manual'，防止后续自动清理时被删除
	apt-mark auto '.*' > /dev/null; \
	{ [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; }; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual; \
	\
# 删除安装的临时依赖软件包，清理缓存
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false ${fetchDeps}; \
	apt-get autoclean -y; \
	rm -rf /var/lib/apt/lists/*; \
	:;

# 执行预处理脚本，并验证安装的软件包
RUN set -eux; \
	override_file="/usr/local/overrides/overrides-${APP_VERSION}.sh"; \
	[ -e "${override_file}" ] && /bin/bash "${override_file}"; \
# 验证安装的软件是否可以正常运行，常规情况下放置在命令行的最后
	gosu ${APP_USER} openssl version; \
	\
	gosu ${APP_USER} erl -noshell -eval 'io:format("~p~n~n~p~n~n", [crypto:supports(), ssl:versions()]), init:stop().'; \
	\
	export RABBITMQ_HOME=${APP_HOME_DIR}; \
	[ ! -e "$APP_DATA_DIR/.erlang.cookie" ]; \
	gosu ${APP_USER} rabbitmqctl help; \
	gosu ${APP_USER} rabbitmqctl list_ciphers; \
	gosu ${APP_USER} rabbitmq-plugins list; \
	rm -rf "${APP_DATA_DIR}/.erlang.cookie"; \
	:;

# 默认提供的数据卷
VOLUME ["/srv/conf", "/srv/data", "/srv/datalog", "/srv/cert", "/var/log"]

# 默认使用gosu切换为新建用户启动，必须保证端口在1024之上
EXPOSE 4369 5671 5672 15671 15672 61613 61614 1883 8883

# 容器初始化命令，默认存放在：/usr/local/bin/entry.sh
ENTRYPOINT ["entry.sh"]

WORKDIR ${APP_DATA_DIR}

# 应用程序的服务命令，必须使用非守护进程方式运行。如果使用变量，则该变量必须在运行环境中存在（ENV可以获取）
CMD ["${APP_EXEC}"]
