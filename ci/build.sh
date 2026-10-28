#!/bin/bash

# 设置变量
web_server=nginx
php_vers=(8.2 8.3 8.4 8.5)
push=false

# 参数解析：默认只构建，-p / --push 才推送
for arg in "$@"
do
    case "$arg" in
        -p|--push) push=true ;;
        *) echo "Unknown option: $arg (usage: $0 [-p|--push])"; exit 1 ;;
    esac
done

# 错误检查
set -e

# 推送前判断是否已登录 Docker Hub
if [ "$push" = true ]; then
    if ! docker system info 2>/dev/null | grep -q '^ *Username:'; then
        echo "Not logged in to Docker Hub, please run 'docker login' first."
        exit 1
    fi
fi

# 构建后按需推送
build_and_push() {
    local tag="$1"
    shift
    docker build -t "$tag" "$@" .
    echo "Image ${tag} built successfully!"
    if [ "$push" = true ]; then
        docker push "$tag"
    fi
}

for php_ver in "${php_vers[@]}"
do
    build_and_push "wdssmq/zblogphp-${web_server}:${php_ver}" \
        --build-arg WEB_SERVER="${web_server}" \
        --build-arg PHP_VER="${php_ver}"
done

# 默认版本
build_and_push "wdssmq/zblogphp-${web_server}:latest" \
    --build-arg WEB_SERVER="${web_server}" \
    --build-arg PHP_VER="8.2"

# 这里不传参数，使用 Dockerfile 内的默认值（Nginx + PHP 8.2）
build_and_push "wdssmq/zblogphp:latest"

# # 一个年月版本的 tag
# build_and_push "wdssmq/zblogphp:$(date +%y.%m)"

# 清理无用的镜像和容器
docker image prune -f
docker container prune -f
