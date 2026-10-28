ARG WEB_SERVER=nginx
ARG PHP_VER=8.2

FROM webdevops/php-${WEB_SERVER}:${PHP_VER}

LABEL maintainer="zblogcn"
LABEL version="2.0"
LABEL description="Z-BlogPHP Docker Image"

VOLUME /app

COPY nginx/vhost.common.d/10-location-root.conf /opt/docker/etc/nginx/vhost.common.d/10-location-root.conf

EXPOSE 80

ENV ZC_SKIP_CHMOD=0
# 安装包需包含 CLI 安装器 zb_install/cli.php（1.7.5.3550 及以上）
ENV ZC_INSTALL_URL=https://github.com/zblogcn/zblogphp/releases/download/v1.7.5.3550/zblogphp-1.7.5.3550.zip
ENV ZC_INSTALL_NAME=""

# zba_toolkit.php 来自 Z-BlogPHP 仓库的 utils/zba_toolkit.php（发布包中不含该目录）
COPY utils/zba_toolkit.php /root/zba_toolkit.php

COPY docker_entrypoint.sh /entrypoint.d
