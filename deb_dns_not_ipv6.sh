#!/bin/bash

# ====================================================================
# Debian 13 (Trixie) 纯 IPv4 DNS 缓存一键安装与极致优化脚本
# ====================================================================

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 root 权限或 sudo 运行此脚本！"
    exit 1
fi

echo "🚀 开始配置纯 IPv4 环境及 dnsmasq 本地 DNS 缓存..."

# --------------------------------------------------------------------
# 第一步：彻底在内核和引导层面禁用 IPv6
# --------------------------------------------------------------------
echo "📦 1. 正在从内核层面彻底拔除 IPv6..."

# 写入 sysctl 禁用参数
cat <<EOF > /etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

# 立即应用内核参数
sysctl --system >/dev/null 2>&1

# 修改 GRUB 引导参数以防重启后死灰复燃
if [ -f /etc/default/grub ]; then
    # 检查是否已经包含该参数
    if ! grep -q "ipv6.disable=1" /etc/default/grub; then
        # 无论原本是用单引号、双引号，还是末尾有其他参数，都安全地追加到末尾
        sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/s/["'\'']$/ ipv6.disable=1"/' /etc/default/grub
        sed -i 's/"" ipv6.disable=1"/ "ipv6.disable=1"/' /etc/default/grub
        # 更新 GRUB 引导
        update-grub >/dev/null 2>&1
        echo "   [✓] GRUB 引导参数已更新 (ipv6.disable=1)"
    else
        echo "   [-] GRUB 引导参数已存在，无需重复添加"
    fi
fi

# --------------------------------------------------------------------
# 第二步：安装并配置纯 IPv4 版 dnsmasq
# --------------------------------------------------------------------
echo "📦 2. 正在更新源并安装 dnsmasq..."
apt-get update -y >/dev/null 2>&1
apt-get install dnsmasq -y >/dev/null 2>&1

echo "⚙️ 3. 正在配置 dnsmasq (纯 IPv4 极致优化)..."

# 备份原配置
[ -f /etc/dnsmasq.conf ] && cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak

# 写入全新的纯 IPv4 dnsmasq 配置
cat <<EOF > /etc/dnsmasq.conf
# 基础优化配置
listen-address=127.0.0.1
port=53
cache-size=5000
bogus-priv
domain-needed

# 纯 IPv4 核心优化：直接拦截并丢弃所有 IPv6 (AAAA) 解析请求
filter-AAAA

# 纯 IPv4 优质公网全网加速上游 DNS
server=8.8.8.8
server=1.1.1.1
EOF

# 重启 dnsmasq 服务
systemctl restart dnsmasq
systemctl enable dnsmasq >/dev/null 2>&1

# --------------------------------------------------------------------
# 第三步：清理、接管并锁死 resolv.conf
# --------------------------------------------------------------------
echo "🔒 4. 正在清理并强行锁定 /etc/resolv.conf..."

# 解除可能的历史锁定
chattr -i /etc/resolv.conf >/dev/null 2>&1

# 写入唯一的纯 IPv4 本地环回解析
cat <<EOF > /etc/resolv.conf
# 纯 IPv4 本地 DNS 缓存接管
nameserver 127.0.0.1
EOF

# 强行锁死文件，防止 Linode Network Helper 或系统重启重写它
chattr +i /etc/resolv.conf

# --------------------------------------------------------------------
# 第四步：清理系统 hosts 中的 IPv6 残留
# --------------------------------------------------------------------
if [ -f /etc/hosts ]; then
    sed -i 's/^::1/#::1/' /etc/hosts
fi

echo "===================================================================="
echo "🎯 【大功告成】纯 IPv4 环境与 DNS 缓存配置完毕！"
echo "⚠️  【重要提示】为了让内核彻底剥离 IPv6 模块，请执行一次重启："
echo "   👉 命令: sudo reboot"
echo "===================================================================="
