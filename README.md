# zblogphp-docker

基于 `webdevops/php-nginx`，默认支持伪静态。

项目地址：[https://github.com/zblogcn/zblogphp-docker-image](https://github.com/zblogcn/zblogphp-docker-image "GitHub - zblogcn/zblogphp-docker-image")

## 使用 Docker Compose 部署「推荐」

wdssmq/zbp-docker-compose: 使用 Docker Compose 快捷部署 Z-BlogPHP + MySQL；：

[https://github.com/wdssmq/zbp-docker-compose](https://github.com/wdssmq/zbp-docker-compose "wdssmq/zbp-docker-compose: 使用 Docker Compose 快捷部署 Z-BlogPHP + MySQL；")

## 实际可用镜像及 TAG

- `wdssmq/zblogphp`
    - `wdssmq/zblogphp:latest` - Nginx + PHP 8.2（Dockerfile 默认）
- `wdssmq/zblogphp-nginx`
    - `wdssmq/zblogphp-nginx:latest` - 同 8.2
    - `wdssmq/zblogphp-nginx:8.5`    - Nginx + PHP 8.5
    - `wdssmq/zblogphp-nginx:8.4`    - Nginx + PHP 8.4
    - `wdssmq/zblogphp-nginx:8.3`    - Nginx + PHP 8.3
    - `wdssmq/zblogphp-nginx:8.2`    - Nginx + PHP 8.2

> PHP 7.4 / 8.0 / 8.1 已不再构建；

## 构建和调试

构建镜像

```bash
# 克隆项目并进入目录
git clone git@github.com:zblogcn/zblogphp-docker-image.git zbp-docker-image
cd zbp-docker-image

# Build
docker build -t zblogcn/zblogphp .

# 指定 PHP 版本
docker build -t zblogcn/zblogphp:8.2 --build-arg PHP_VER="8.2" .

```
运行：

```bash
mkdir -p ~/www/zbp
# docker rm --force zbp
docker run --rm --name zbp \
  -v ~/www/zbp:/app \
  -e ZC_DB_HOST=host.docker.internal \
  -e ZC_DB_NAME=zblog_docker \
  -e ZC_DB_USER=root \
  -e ZC_DB_PWDD= \
  -e ZC_BLOG_USER=admin \
  -e ZC_BLOG_PWDD=shezhidemima \
  -p 8288:80 zblogcn/zblogphp
# exit

```

> 实际使用还是建议用 `Docker Compose`；

正式运行将 `--rm` 参数改为 `-d`；

## 注意事项

镜像内不包含数据库；通过 `host.docker.internal` 可访问宿主环境，或者使用数据库容器 ID；

安装过程由 Z-BlogPHP 自带的 CLI 安装器 `zb_install/cli.php` 完成，因此安装包需为 `1.7.5.3550` 及以上版本；

管理员密码没有默认值，必须通过 `-e ZC_BLOG_PWDD=<密码>` 指定，否则安装会直接失败；管理员账号长度需在 2-50 之间，密码长度需在 8-40 之间（CLI 安装器会校验）；

详细变量说明，使用 `-e ZC_DB_PREFIX=pre_` 指定：

```
ZC_DB_TYPE     数据库类型，sqlite3 / mysqli / pdo_mysql / pgsql 等，默认 mysqli
ZC_DB_HOST     数据库地址，默认 localhost，可写成 host:port 形式
ZC_DB_PORT     数据库端口，留空时按类型自动取 3306 / 5432
ZC_DB_NAME     数据库名，默认 zblog_docker；SQLite 留空则由安装器自动生成文件名
ZC_DB_USER     数据库用户名，默认 root
ZC_DB_PWDD     数据库密码 （MySQL 无密码时留空即可）
ZC_DB_PREFIX   表前缀，默认 zbp_
ZC_DB_ENGINE   MySQL 存储引擎，默认 MyISAM
ZC_BLOG_NAME   站点名称，默认「又一个 Z-BLOG 站点」
ZC_BLOG_USER   管理员账号，默认 zblog_user
ZC_BLOG_PWDD   管理员密码，无默认值，必填
ZC_BLOG_THEME  主题和样式，格式「主题|样式」，默认 tpure|style
```


对于挂载文件夹 `~/www/zbp`，其中的权限应为 `1000:1000`，可使用命令 `chown -R 1000:1000 ~/www/zbp` 修改；

「可选」`-e ZC_INSTALL_URL=https://github.com/zblogcn/zblogphp/releases/download/v1.7.5.3550/zblogphp-1.7.5.3550.zip` 可指定安装包地址；

「可选」`-e ZC_INSTALL_NAME=Z-BlogPHP_1_7_5_3540_Optimus` 可指定 update.zblogcn.com 上的安装包名称，设置后优先于 `ZC_INSTALL_URL`；

「可选」`-e ZC_SKIP_CHMOD=1` —— 跳过文件权限变更，适用于插件开发等文件较多的场景，此时需要自行确保具体文件的写入权限；

镜像内附带 `/root/zba_toolkit.php`，可在容器内手动安装应用：

```bash
php /root/zba_toolkit.php sync /tmp/AppCentre.zba /app -f
```

