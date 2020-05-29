FROM colovu/ubuntu:18.04

ARG app_ver=3.7.25

ENV APP_NAME=rabbitmq \
	APP_EXEC=rabbitmq-server \
	APP_USER=rabbitmq \
	APP_GROUP=rabbitmq \
	APP_VERSION=${app_ver} \
	OTP_VERSION=22.3.2 \
	OPENSSL_VERSION=1.1.1g

ENV	APP_DEF_DIR=/etc/${APP_NAME} \
	APP_CONF_DIR=/srv/conf/${APP_NAME} \
	APP_DATA_DIR=/srv/data/${APP_NAME} \
	APP_CACHE_DIR=/var/cache/${APP_NAME} \
	APP_RUN_DIR=/var/run/${APP_NAME} \
	APP_LOG_DIR=/var/log/${APP_NAME} \
	APP_CERT_DIR=/srv/cert/${APP_NAME} \
	RABBITMQ_HOME=/usr/local/rabbitmq \
	RABBITMQ_LOGS=-

ENV LANG=C.UTF-8 \
	LANGUAGE=C.UTF-8 \
	LC_ALL=C.UTF-8 \
	HOME=${APP_DATA_DIR} \
	PATH="/usr/local/bin/colovu:/usr/local/bin/app:${RABBITMQ_HOME}/sbin:${PATH}"

LABEL \
	"Version"="v${APP_VERSION}" \
	"Description"="Docker image for ${APP_NAME} ${APP_VERSION}." \
	"Dockerfile"="https://github.com/colovu/docker-${APP_NAME}" \
	"Vendor"="Endial Fang (endial@126.com)"

COPY prebuilds /

# 安装 OpenSSL
RUN set -eux; \
# 设置程序使用静默安装，而非交互模式；类似tzdata等程序需要使用静默安装
	export DEBIAN_FRONTEND=noninteractive; \
	\
# 安装临时使用的软件包，在使用完后会进行删除
	fetchDeps=" \
		curl \
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
	"; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ${fetchDeps}; \
	\
	\
# 使用下载方式安装OpenSSL
	OPENSSL_SOURCE_URL="https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz"; \
	OPENSSL_SOURCE_SHA256="ddb04774f1e32f0c49751e21b67216ac87852ceb056b75209af2443400636d46"; \
	OPENSSL_PGP_KEY_IDS="0x8657ABB260F056B1E5190839D9C4D26D0E604491 0x5B2545DAB21995F4088CEFAA36CEE4DEB00CFE33 0xED230BEC4D4F2518B9D7DF41F0DB4D21C1D35231 0xC1F33DD8CE1D4CC613AF14DA9195C48241FBF7DD 0x7953AC1FBC3DC8B3B292393ED5E9E43F7DF9EE8C 0xE5E52560DD91C556DDBDA5D02064C53641C25E5D"; \
	OPENSSL_PATH="/usr/local/src/openssl-${OPENSSL_VERSION}"; \
	OPENSSL_CONFIG_DIR=/usr/local/etc/ssl; \
	\
	curl --progress-bar -L -o openssl-${OPENSSL_VERSION}.tar.gz ${OPENSSL_SOURCE_URL}; \
	curl --progress-bar -L -o openssl-${OPENSSL_VERSION}.tar.gz.asc ${OPENSSL_SOURCE_URL}.asc; \
	\
# 下载方式安装软件，使用GPG签名方式验证软件
	export GNUPGHOME="$(mktemp -d)"; \
	for key in ${OPENSSL_PGP_KEY_IDS}; do \
		gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "${key}"|| \
		gpg --batch --keyserver pgp.mit.edu --recv-keys "${key}" || \
		gpg --batch --keyserver keys.gnupg.net --recv-keys "${key}" || \
		gpg --batch --keyserver keyserver.pgp.com --recv-keys "${key}"; \
	done; \
	gpg --batch --verify "openssl-${OPENSSL_VERSION}.tar.gz.asc" "openssl-${OPENSSL_VERSION}.tar.gz"; \
	command -v gpgconf > /dev/null && gpgconf --kill all; \
	rm -rf "$GNUPGHOME"; \
	\
	mkdir -p /openssl-${OPENSSL_VERSION}; \
	tar --extract --file "openssl-${OPENSSL_VERSION}.tar.gz" --directory "/openssl-${OPENSSL_VERSION}" --strip-components 1; \
	cd /openssl-${OPENSSL_VERSION}; \
	debMultiarch="$(dpkg-architecture --query DEB_HOST_MULTIARCH)"; \
	MACHINE="$(dpkg-architecture --query DEB_BUILD_GNU_CPU)" \
	RELEASE="4.x.y-z" SYSTEM='Linux' BUILD='???' ./config \
		--openssldir="${OPENSSL_CONFIG_DIR}" \
		--libdir="lib/${debMultiarch}" \
		-Wl,-rpath=/usr/local/lib \
	; \
	make -j "$(getconf _NPROCESSORS_ONLN)"; \
	make install_sw install_ssldirs; \
	cd /; \
	rm -rf "/openssl-${OPENSSL_VERSION}" openssl-${OPENSSL_VERSION}.tar.gz openssl-${OPENSSL_VERSION}.tar.gz.asc; \
	ldconfig; \
# 使用 Ubuntu的 CA certificates
	rmdir "${OPENSSL_CONFIG_DIR}/certs" "${OPENSSL_CONFIG_DIR}/private"; \
	ln -sf /etc/ssl/certs /etc/ssl/private "${OPENSSL_CONFIG_DIR}"; \
	\
# 查找新安装的应用依赖软件包，并标识为'manual'，防止后续自动清理时被删除
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
	\
# 验证安装的软件是否可以正常运行，常规情况下放置在命令行的最后
	openssl version;

# 安装 ErLang
RUN set -eux; \
# 设置程序使用静默安装，而非交互模式；类似tzdata等程序需要使用静默安装
	export DEBIAN_FRONTEND=noninteractive; \
	\
# 安装临时使用的软件包，在使用完后会进行删除
	fetchDeps=" \
		curl \
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
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ${fetchDeps}; \
	\
# 使用下载方式安装ErLang
	OTP_SOURCE_URL="https://github.com/erlang/otp/archive/OTP-${OTP_VERSION}.tar.gz"; \
	OTP_SOURCE_SHA256="4a3719c71a7998e4f57e73920439b4b1606f7c045e437a0f0f9f1613594d3eaa"; \
	OTP_PATH="/usr/local/src/otp-${OTP_VERSION}"; \
	\
	curl --progress-bar -L -o otp-${OTP_VERSION}.tar.gz ${OTP_SOURCE_URL}; \
	echo "$OTP_SOURCE_SHA256 *otp-${OTP_VERSION}.tar.gz" | sha256sum --check --strict -; \
	\
	mkdir -p /otp-${OTP_VERSION}; \
	tar --extract --file "otp-${OTP_VERSION}.tar.gz" --directory "/otp-${OTP_VERSION}" --strip-components 1; \
	cd /otp-${OTP_VERSION}; \
	export ERL_TOP="/otp-${OTP_VERSION}"; \
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
	make -j "$(getconf _NPROCESSORS_ONLN)" GEN_OPT_FLGS="-O2 -fno-strict-aliasing"; \
	make install; \
	cd /; \
	rm -rf \
		"/otp-${OTP_VERSION}" \
		/usr/local/lib/erlang/lib/*/examples \
		/usr/local/lib/erlang/lib/*/src \
	; \
	\
# 查找新安装的应用依赖软件包，并标识为'manual'，防止后续自动清理时被删除
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
	\
# 验证安装的软件是否可以正常运行，常规情况下放置在命令行的最后
	erl -noshell -eval 'io:format("~p~n~n~p~n~n", [crypto:supports(), ssl:versions()]), init:stop().';

# 安装 RabbitMQ
RUN set -eux; \
# 设置程序使用静默安装，而非交互模式；类似tzdata等程序需要使用静默安装
	export DEBIAN_FRONTEND=noninteractive; \
	\
# 为应用创建对应的组、用户、相关目录
	groupadd -r ${APP_GROUP}; \
	useradd -r -g ${APP_GROUP} -s /usr/sbin/nologin -d /usr/cache/${APP_NAME} ${APP_USER}; \
	mkdir -p ${APP_DEF_DIR} ${APP_CONF_DIR} ${APP_CERT_DIR} ${APP_DATA_DIR} ${APP_CACHE_DIR} ${APP_LOG_DIR} ${APP_RUN_DIR}; \
	\
# 安装临时使用的软件包，在使用完后会进行删除
	fetchDeps=" \
		curl \
		ca-certificates \
		\
		gnupg \
		dirmngr \
		xz-utils \
	"; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ${fetchDeps}; \
	\
# 使用下载方式安装RabbitMQ
	APP_URL="https://github.com/rabbitmq/rabbitmq-server/releases/download/v$APP_VERSION/rabbitmq-server-generic-unix-latest-toolchain-$APP_VERSION.tar.xz"; \
	APP_PGP_KEY_ID="0x0A9AF2115F4687BD29803A206B73A36E6026DFCA"; \
	curl --progress-bar -L -o ${APP_NAME}-${APP_VERSION}.tar.xz ${APP_URL}; \
	curl --progress-bar -L -o ${APP_NAME}-${APP_VERSION}.tar.xz.asc ${APP_URL}.asc; \
	\
# 下载方式安装软件，使用GPG签名方式验证软件
	export GNUPGHOME="$(mktemp -d)"; \
	for key in ${APP_PGP_KEY_ID}; do \
		gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "${key}"|| \
		gpg --batch --keyserver pgp.mit.edu --recv-keys "${key}" || \
		gpg --batch --keyserver keys.gnupg.net --recv-keys "${key}" || \
		gpg --batch --keyserver keyserver.pgp.com --recv-keys "${key}"; \
	done; \
	gpg --batch --verify "${APP_NAME}-${APP_VERSION}.tar.xz.asc" "${APP_NAME}-${APP_VERSION}.tar.xz"; \
	command -v gpgconf > /dev/null && gpgconf --kill all; \
	rm -rf "$GNUPGHOME"; \
	\
	mkdir -p ${RABBITMQ_HOME}; \
	tar --extract --file "${APP_NAME}-${APP_VERSION}.tar.xz" --directory "${RABBITMQ_HOME}" --strip-components 1; \
# 将 SYS_PREFIX 设置为空，而不要设置为 RABBITMQ_HOME
	grep -qE '^SYS_PREFIX=\$\{RABBITMQ_HOME\}$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	sed -i 's/^SYS_PREFIX=.*$/SYS_PREFIX=/' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	grep -qE '^SYS_PREFIX=$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	chown -R rabbitmq:rabbitmq "$RABBITMQ_HOME"; \
	rm -rf ${APP_NAME}-${APP_VERSION}.tar.xz ${APP_NAME}-${APP_VERSION}.tar.xz.asc; \
	\
# 设置临时目录的权限信息，设置为777是为了保证后续使用`--user`或`gosu`时，可以更改目录对应的用户属性信息；运行时会被更改为700或755
	chown -Rf ${APP_USER}:${APP_GROUP} ${APP_DEF_DIR} ${APP_CONF_DIR} ${APP_DATA_DIR} ${APP_CACHE_DIR} ${APP_LOG_DIR} ${APP_RUN_DIR}; \
	chmod 777 ${APP_DEF_DIR} ${APP_CONF_DIR} ${APP_DATA_DIR} ${APP_CACHE_DIR} ${APP_LOG_DIR} ${APP_RUN_DIR}; \
	\
# 查找新安装的应用依赖软件包，并标识为'manual'，防止后续自动清理时被删除
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
	\
# 验证安装的软件是否可以正常运行，常规情况下放置在命令行的最后
	[ ! -e "$APP_DATA_DIR/.erlang.cookie" ]; \
	gosu rabbitmq rabbitmqctl help; \
	gosu rabbitmq rabbitmqctl list_ciphers; \
	gosu rabbitmq rabbitmq-plugins list; \
	rm "$RABBITMQ_DATA_DIR/.erlang.cookie";

VOLUME ["/srv/conf", "/srv/data", "/srv/cert", "/var/log", "/var/run"]

# 默认使用gosu切换为新建用户启动，必须保证端口在1024之上
EXPOSE 4369 5671 5672 15672 25672

# 容器初始化命令，默认存放在：/usr/local/bin/app/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# 应用程序的服务命令，必须使用非守护进程方式运行
CMD [ "rabbitmq-server" ]
