#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 权限或 sudo 运行此脚本！"
  exit 1
fi

# 获取用户输入的 Swap 大小
SWAP_SIZE=$1

# 如果用户没有在命令行提供参数，则提示输入
if [ -z "$SWAP_SIZE" ]; then
    read -p "请输入您想要设置的虚拟内存大小 (例如 2G, 4G, 2048M): " SWAP_SIZE
fi

# 去掉输入中的空格并转换为大写
SWAP_SIZE=$(echo "$SWAP_SIZE" | tr -d ' ' | tr '[:lower:]' '[:upper:]')

# 校验输入格式是否正确 (如 4G, 2048M)
if [[ ! "$SWAP_SIZE" =~ ^[0-9]+[GM]$ ]]; then
    echo "❌ 输入格式错误！请输入数字加单位，例如: 2G 或 2048M"
    exit 1
fi

SWAP_FILE="/swapfile"

echo "----------------------------------------"
echo "🚀 开始全自动配置虚拟内存 (Swap)..."
echo "----------------------------------------"

# 1. 检查并清理旧的 Swap 文件
if [ -f "$SWAP_FILE" ]; then
    echo "🔄 检测到已存在旧的 Swap 文件 ($SWAP_FILE)，正在清理..."
    swapoff "$SWAP_FILE" 2>/dev/null
    rm -f "$SWAP_FILE"
    # 清理 /etc/fstab 中的旧配置
    sed -i "\|$SWAP_FILE|d" /etc/fstab
    echo "✅ 旧的 Swap 已成功清理。"
fi

# 2. 创建新的 Swap 文件
echo "📂 正在分配 $SWAP_SIZE 的磁盘空间..."
# 优先使用 fallocate（速度快），如果失败则降级使用 dd
if ! fallocate -l "$SWAP_SIZE" "$SWAP_FILE" 2>/dev/null; then
    echo "⚠️ fallocate 失败，正在尝试使用 dd 命令（这可能需要一点时间）..."
    # 解析单位和数字用于 dd
    NUM=$(echo "$SWAP_SIZE" | grep -oE '^[0-9]+')
    UNIT=$(echo "$SWAP_SIZE" | grep -oE '[GM]$')
    if [ "$UNIT" = "G" ]; then
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((NUM * 1024)) status=progress
    else
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$NUM status=progress
    fi
fi

# 3. 设置权限
echo "🔒 正在设置文件权限 (600)..."
chmod 600 "$SWAP_FILE"

# 4. 格式化为 Swap
echo "⚙️ 正在格式化为 Swap 分区..."
mkswap "$SWAP_FILE" >/dev/null

# 5. 启用 Swap
echo "🔛 正在启用新 Swap..."
swapon "$SWAP_FILE"

# 6. 设置永久挂载（写入 /etc/fstab）
echo "💾 正在配置开机自动挂载..."
echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab

# 7. 优化 Swappiness（可选，默认设为 10，减少对硬盘的频繁读写）
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
    echo "vm.swappiness=10" >> /etc/sysctl.conf
else
    sed -i 's/vm.swappiness=.*/vm.swappiness=10/g' /etc/sysctl.conf
fi
sysctl -p >/dev/null

echo "----------------------------------------"
echo "🎉 虚拟内存配置完成！当前内存状态如下："
echo "----------------------------------------"
free -h
