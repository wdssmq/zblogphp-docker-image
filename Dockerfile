ARG WEB_SERVER=nginx
ARG PHP_VER=8.2

FROM webdevops/php-${WEB_SERVER}:${PHP_VER}

LABEL maintainer="zblogcn"
LABEL version="2.0"
LABEL description="Z-BlogPHP Docker Image"

VOLUME /app

COPY nginx/vhost.common.d/10-location-root.conf /opt/docker/etc/nginx/vhost.common.d/10-location-root.conf

EXPOSE 80

ENV ZC_SKIP_TC_PLUGINS 0
ENV ZC_SKIP_CHMOD 0
ENV ZC_INSTALL_NAME Z-BlogPHP_1_7_3_3290_Finch

# ADD install-docker.php /app/install-docker.php
# ADD install-docker-plugins.php /app/install-docker-plugins.php

COPY install-docker.php /root/install-docker.php
COPY install-docker-plugins.php /root/install-docker-plugins.php

COPY docker_entrypoint.sh /entrypoint.d
