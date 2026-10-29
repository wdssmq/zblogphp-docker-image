#!/bin/bash
# Z-BlogPHP 容器初始化：
#   1. 下载并解压 Z-BlogPHP
#   2. 使用 Z-BlogPHP 自带的 CLI 安装器 (zb_install/cli.php) 完成安装
#   3. 使用 zba_toolkit.php (CLI) 安装应用中心
#   4. 清理安装目录并修正权限

DOCKER_UID=${DOCKER_UID:-1000}
DOCKER_GID=${DOCKER_GID:-1000}

set -e

cd /app

# ---------- 环境变量默认值 ----------

# 数据库（参数与 zb_install/cli.php 一致）
ZC_DB_TYPE=${ZC_DB_TYPE:-mysqli}
ZC_DB_HOST=${ZC_DB_HOST:-localhost}
ZC_DB_PORT=${ZC_DB_PORT:-}
ZC_DB_USER=${ZC_DB_USER:-root}
ZC_DB_PWDD=${ZC_DB_PWDD:-}
ZC_DB_PREFIX=${ZC_DB_PREFIX:-zbp_}
ZC_DB_ENGINE=${ZC_DB_ENGINE:-MyISAM}
# 安装前等待数据库端口就绪的超时秒数，0 表示不等待
ZC_DB_WAIT_TIMEOUT=${ZC_DB_WAIT_TIMEOUT:-60}
# SQLite 时留空，由 cli.php 自动生成数据库文件名
case "$ZC_DB_TYPE" in
    sqlite | sqlite3 | pdo_sqlite) ZC_DB_NAME=${ZC_DB_NAME:-} ;;
    *) ZC_DB_NAME=${ZC_DB_NAME:-zblog_docker} ;;
esac

# 站点和管理员（密码不设默认值）
ZC_BLOG_NAME=${ZC_BLOG_NAME:-又一个 Z-BLOG 站点}
ZC_BLOG_USER=${ZC_BLOG_USER:-zblog_user}
# 格式：主题|样式，如 default|default、tpure|style
ZC_BLOG_THEME=${ZC_BLOG_THEME:-tpure|style}

# 安装包：ZC_INSTALL_URL 为完整地址，ZC_INSTALL_NAME 对应 update.zblogcn.com/zip/<名称>.zip
ZC_INSTALL_URL=${ZC_INSTALL_URL:-https://github.com/zblogcn/zblogphp/releases/download/v1.7.5.3550/zblogphp-1.7.5.3550.zip}
ZC_INSTALL_NAME=${ZC_INSTALL_NAME:-}

ZC_SKIP_CHMOD=${ZC_SKIP_CHMOD:-0}

# 预装应用：ZC_APP_URLS_CONFIG 每行一个「名称=下载地址」
ZC_APPS_AUTO=${ZC_APPS_AUTO:-0}
ZC_TOOLKIT=${ZC_TOOLKIT:-/root/zba_toolkit.php}

ZC_APP_URLS_CONFIG=${ZC_APP_URLS_CONFIG:-}
declare -A ZC_APP_URLS=()
app_list=()

if [ -n "$ZC_APP_URLS_CONFIG" ]; then
    # 一行一个：名称=地址，忽略空行和 # 注释
    while IFS= read -r app_url_entry || [ -n "$app_url_entry" ]; do
        app_url_entry="${app_url_entry%$'\r'}"
        app_url_entry="${app_url_entry#"${app_url_entry%%[![:space:]]*}"}"
        app_url_entry="${app_url_entry%"${app_url_entry##*[![:space:]]}"}"
        case "$app_url_entry" in "" | "#"*) continue ;; esac
        if [[ "$app_url_entry" != *=* ]]; then
            echo "Error: ZC_APP_URLS_CONFIG 条目格式无效: ${app_url_entry}" >&2
            exit 1
        fi

        app_name="${app_url_entry%%=*}"
        app_url="${app_url_entry#*=}"
        if [ -z "$app_name" ] || [ -z "$app_url" ]; then
            echo "Error: ZC_APP_URLS_CONFIG 的应用名和下载地址不能为空。" >&2
            exit 1
        fi
        if [ -z "${ZC_APP_URLS[$app_name]+set}" ]; then
            app_list+=("$app_name")
        fi
        ZC_APP_URLS["$app_name"]="$app_url"
    done <<<"$ZC_APP_URLS_CONFIG"
fi

# ---------- 下载（带重试） ----------

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

# ---------- 下载并解压 Z-BlogPHP ----------

if [ ! -s /app/index.php ] || [ ! -d /app/zb_system ]; then
    rm -f /app/index.php

    if [ -n "$ZC_INSTALL_NAME" ]; then
        package_url="https://update.zblogcn.com/zip/${ZC_INSTALL_NAME}.zip"
    else
        package_url="$ZC_INSTALL_URL"
    fi

    echo Downloading Z-BlogPHP...
    if ! download_with_retry -O /app/zblogphp-package.zip "$package_url"; then
        echo "Error: Failed to download Z-BlogPHP: ${package_url}" >&2
        rm -f /app/zblogphp-package.zip
        exit 1
    fi

    echo Unpacking Z-BlogPHP...
    unzip -oq /app/zblogphp-package.zip
    echo Delete zip
    rm -f /app/zblogphp-package.zip
fi

# 验证文件
if [ ! -s /app/index.php ]; then
    echo "Error: Failed to download Z-BlogPHP" >&2
    exit 1
fi

# ---------- 等待数据库就绪 ----------

# 与 cli.php 的规则一致：端口为空时按类型取默认值，ZC_DB_HOST 也可写成 host:port
db_host="$ZC_DB_HOST"
db_port="$ZC_DB_PORT"
if [ -z "$db_port" ] && [ "1" = "$(printf '%s' "$db_host" | tr -cd ':' | wc -c)" ]; then
    db_port="${db_host##*:}"
    db_host="${db_host%:*}"
fi
if [ -z "$db_port" ]; then
    case "$ZC_DB_TYPE" in
        postgresql | pdo_postgresql) db_port=5432 ;;
        *) db_port=3306 ;;
    esac
fi

wait_for_db() {
    local timeout="$ZC_DB_WAIT_TIMEOUT"
    local waited=0

    if [ "$timeout" -le 0 ]; then
        return 0
    fi

    echo "Waiting for database ${db_host}:${db_port} ..."
    while [ "$waited" -lt "$timeout" ]; do
        if timeout 2 bash -c "cat < /dev/null > /dev/tcp/${db_host}/${db_port}" 2>/dev/null; then
            echo "Database is ready."
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
    done

    echo "Error: 等待数据库超时 (${timeout}s): ${db_host}:${db_port}" >&2
    return 1
}

# ---------- 使用 CLI 安装器安装 ----------

if [ ! -e /app/zb_users/c_option.php ]; then
    echo Installing Z-BlogPHP...

    case "$ZC_DB_TYPE" in
        sqlite | sqlite3 | pdo_sqlite) ;;
        *) wait_for_db ;;
    esac

    # 管理员密码没有默认值，避免装出一个使用默认口令的站点
    if [ -z "$ZC_BLOG_PWDD" ]; then
        echo "Error: 必须指定管理员密码，使用 -e ZC_BLOG_PWDD=<密码>（长度 8-40）。" >&2
        exit 1
    fi

    if [ ! -e /app/zb_install/cli.php ]; then
        echo "Error: 当前版本没有 CLI 安装器 (zb_install/cli.php)，请改用 1.7.5.3550 及以上版本的安装包。" >&2
        exit 1
    fi

    # 所有可选参数都使用 --key=value 形式，避免空值被当成布尔参数
    php /app/zb_install/cli.php \
        --db-type="$ZC_DB_TYPE" \
        --db-server="$ZC_DB_HOST" \
        --db-port="$ZC_DB_PORT" \
        --db-name="$ZC_DB_NAME" \
        --db-user="$ZC_DB_USER" \
        --db-password="$ZC_DB_PWDD" \
        --db-prefix="$ZC_DB_PREFIX" \
        --db-engine="$ZC_DB_ENGINE" \
        --site-name="$ZC_BLOG_NAME" \
        --admin-user="$ZC_BLOG_USER" \
        --admin-password="$ZC_BLOG_PWDD" \
        --theme="$ZC_BLOG_THEME"
fi

# ---------- 安装配置的预装应用 ----------

install_app() {
    local name="$1"
    local url="$2"
    local zba_file="${app_dir}/${name}.zba"

    echo "Installing ${name} ..."
    if ! download_with_retry -O "$zba_file" "$url"; then
        echo "Warning: Failed to download app: ${name}" >&2
        rm -f "$zba_file"
        return 0
    fi

    # sync：删除同名应用后重新解压，-f 用于跳过交互确认
    php "$ZC_TOOLKIT" sync "$zba_file" /app -f
    rm -f "$zba_file"
}

if [ "$ZC_APPS_AUTO" = "1" ] && [ "${#app_list[@]}" -gt 0 ] && [ -e /app/zb_users/c_option.php ]; then
    echo Updating Apps...
    app_dir=$(mktemp -d)
    for app_name in "${app_list[@]}"; do
        app_url="${ZC_APP_URLS[$app_name]:-}"
        install_app "$app_name" "$app_url"
    done
    rm -rf "$app_dir"
fi

# ---------- 清理安装相关文件 ----------

if [ -e /app/zb_users/c_option.php ]; then
    if [ -d /app/zb_install ]; then
        rm -rf /app/zb_install
    fi
fi

# ---------- 权限 ----------

if [ "$ZC_SKIP_CHMOD" = "0" ]; then
    chown -R ${DOCKER_UID}:${DOCKER_GID} /app
    find ./ -type d -print0 | xargs -0 -r chmod 755
    find ./ -type f -print0 | xargs -0 -r chmod 644
fi
