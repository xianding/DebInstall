#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 用户或 sudo 运行此脚本！"
  exit 1
fi

echo "=========================================="
echo "    Debian 13 - Caddy WebDAV 一键安装脚本"
echo "=========================================="

# 1. 让用户输入必要的信息
read -p "请输入你的域名 (例如 webdav.example.com): " DOMAIN
read -p "请输入 WebDAV 用户名 (默认: admin): " USERNAME
USERNAME=${USERNAME:-admin}
read -s -p "请输入 WebDAV 密码: " PASSWORD
echo ""

if [ -z "$DOMAIN" ] || [ -z "$PASSWORD" ]; then
    echo "❌ 域名和密码不能为空！"
    exit 1
fi

# 2. 安装基础依赖
echo "🔄 正在安装基础依赖..."
apt update && apt install -y curl debian-keyring debian-archive-keyring apt-transport-https wget

# 3. 下载带有 webdav 插件的官方 Caddy 二进制文件
echo "📥 正在下载带 WebDAV 插件的 Caddy..."
# 获取最新版带 webdav 插件的 caddy 自定义构建
# 这里直接从官方下载服务获取（包含 mholt/caddy-webdav 插件）
ARCH=$(dpkg --print-architecture)
CADDY_URL="https://caddyserver.com/api/download?os=linux&arch=${ARCH}&p=github.com%2Fmholt%2Fcaddy-webdav"

wget -O /usr/bin/caddy "${CADDY_URL}"
chmod +x /usr/bin/caddy

# 创建 caddy 用户和组
if ! id "caddy" &>/dev/null; then
    useradd --system --user-group --create-home --home-dir /var/lib/caddy --shell /usr/sbin/nologin caddy
fi

# 4. 创建系统服务守护进程 (systemd)
echo "⚙️ 正在配置 Caddy 系统服务..."
cat <<EOF > /etc/systemd/system/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# 5. 创建 WebDAV 共享目录
echo "📁 正在创建 WebDAV 共享目录..."
WEBDAV_DIR="/var/www/webdav"
mkdir -p /etc/caddy
mkdir -p ${WEBDAV_DIR}
chown -R caddy:caddy /var/www/webdav
chown -R caddy:caddy /etc/caddy

# 6. 生成密码哈希
echo "🔑 正在生成加密密码..."
PASSWORD_HASH=$(caddy hash-password --plaintext "${PASSWORD}")

# 7. 写入 Caddyfile 配置文件
echo "📝 正在生成 Caddyfile 配置文件..."
cat <<EOF > /etc/caddy/Caddyfile
{
    order webdav before file_server
}

${DOMAIN} {
    root * ${WEBDAV_DIR}
    
    basic_auth {
        ${USERNAME} ${PASSWORD_HASH}
    }

    webdav {
        root ${WEBDAV_DIR}
    }
    
    file_server
}
EOF

# 8. 启动并开机自启
echo "🚀 正在启动 WebDAV 服务并设置开机自启..."
systemctl daemon-reload
systemctl enable --now caddy

echo "=========================================="
echo "🎉 WebDAV 服务安装并配置成功！"
echo "🌐 访问地址: https://${DOMAIN}"
echo "👤 用户名: ${USERNAME}"
echo "🔒 密码: (你刚才设置的密码)"
echo "📁 存储路径: ${WEBDAV_DIR}"
echo "=========================================="
echo "⚠️  注意：请确保你的域名 DNS 已经解析到此服务器 IP，且 80 和 443 端口已放行。"
