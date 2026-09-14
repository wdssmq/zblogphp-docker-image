#!/bin/bash
ENV DOCKER_UID=1000
ENV DOCKER_GID=1000
set -e
cd /app

if [ ! -e /app/zb_users/c_option.php ]; then
    if [ ! -d /app/zb_install ]; then
        rm -f /app/index.php
    fi
    if [ ! -e /app/install-docker.php ]; then
        cp /root/install-docker.php /app/install-docker.php
    fi
    if [ ! -e /app/install-docker-plugins.php ]; then
        cp /root/install-docker-plugins.php /app/install-docker-plugins.php
    fi
fi

# 下载带重试
download_with_retry() {
    local max_retries=3
    local count=0
    while [ $count -lt $max_retries ]; do
        if wget "$@"; then
            return 0
        fi
        count=$((count + 1))
        sleep 5
    done
    return 1
}

## Download Z-BlogPHP
# ZC_INSTALL_NAME 由 Dockerfile 内定义
if ! [ -e /app/index.php ]; then
    echo Downloading Z-BlogPHP...
    download_with_retry https://update.zblogcn.com/zip/$ZC_INSTALL_NAME.zip
    echo Unpacking Z-BlogPHP...
    unzip -oq $ZC_INSTALL_NAME.zip
    echo Delete zip
    rm /app/$ZC_INSTALL_NAME.zip
fi

# 验证文件
if [ ! -s /app/index.php ]; then
    echo "Error: Failed to download Z-BlogPHP" >&2
    exit 1
fi

# # cd /app
# chown -R www-data:www-data /app
# find ./ -type d -print|xargs chmod 777
# find ./ -type f -print|xargs chmod 777

if [ ! -e /app/zb_users/c_option.php ] && [ -e /app/install-docker.php ]; then
    echo Installing Z-BlogPHP...
    php /app/install-docker.php
fi

if [ "$ZC_SKIP_TC_PLUGINS" -eq "0" ] && [ -e /app/install-docker-plugins.php ]; then
    echo Updating Plugins...
    php /app/install-docker-plugins.php
fi

if [ -e /app/zb_users/c_option.php ]; then
    if [ -d /app/zb_install ]; then
        rm -rf /app/zb_install
    fi
    if [ -e /app/install-docker.php ]; then
        rm /app/install-docker.php
    fi
    if [ -e /app/install-docker-plugins.php ]; then
        rm /app/install-docker-plugins.php
    fi
fi

if [ "$ZC_SKIP_CHMOD" -eq "0" ]; then
    # cd /app
    chown -R ${DOCKER_UID}:${DOCKER_GID} /app
    find ./ -type d -print|xargs chmod 755
    find ./ -type f -print|xargs chmod 644
fi

# echo "$@"
# exec "$@"
