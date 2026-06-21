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

# 统一格式化输入
SWAP_SIZE=$(echo "$SWAP_SIZE" | tr -d ' ' | tr '[:lower:]' '[:upper:]')

# 校验输入格式
if [[ ! "$SWAP_SIZE" =~ ^[0-9]+[GM]$ ]]; then
    echo "❌ 输入格式错误！请输入数字加单位，例如: 2G 或 2048M"
    exit 1
fi

TARGET_SWAP="/swapfile"

echo "----------------------------------------"
echo "🚀 开始全自动智能配置虚拟内存..."
echo "----------------------------------------"

# 1. 智能识别并清理所有现有的旧 Swap 文件
echo "🔍 正在扫描系统现有的虚拟内存..."
# 提取所有类型为 file 的 swap 路径
OLD_SWAPS=$(awk '$2=="file" {print $1}' /proc/swaps)

if [ -n "$OLD_SWAPS" ]; then
    echo "🔄 发现已存在的旧 Swap 文件，正在深度清理..."
    for old_swap in $OLD_SWAPS; do
        echo "  - 正在关闭并移除: $old_swap"
        swapoff "$old_swap" 2>/dev/null
        rm -f "$old_swap"
        # 从 /etc/fstab 中精准擦除该挂载记录
        # 精准匹配：行首或空白后接该路径，且后面跟空白
        sed -i -E "\|^([[:space:]]*|)$old_swap[[:space:]]+|d" /etc/fstab
    done
    echo "✅ 旧的 Swap 文件已全部清理完毕。"
else
    echo "ℹ️ 未检测到已启用的旧 Swap 文件。"
fi

# 额外保险：如果目标路径存在残留文件但未启用，也一并清理
if [ -f "$TARGET_SWAP" ]; then
    rm -f "$TARGET_SWAP"
    sed -i "\|$TARGET_SWAP|d" /etc/fstab
fi

# 2. 创建新的 Swap 文件
echo "📂 正在分配 $SWAP_SIZE 的磁盘空间..."
if ! fallocate -l "$SWAP_SIZE" "$TARGET_SWAP" 2>/dev/null; then
    echo "⚠️ fallocate 失败，正在尝试使用 dd 命令替代..."
    NUM=$(echo "$SWAP_SIZE" | grep -oE '^[0-9]+')
    UNIT=$(echo "$SWAP_SIZE" | grep -oE '[GM]$')
    if [ "$UNIT" = "G" ]; then
        dd if=/dev/zero of="$TARGET_SWAP" bs=1M count=$((NUM * 1024)) status=progress
    else
        dd if=/dev/zero of="$TARGET_SWAP" bs=1M count=$NUM status=progress
    fi
fi

# 3. 设置权限
echo "🔒 正在设置文件权限 (600)..."
chmod 600 "$TARGET_SWAP"

# 4. 格式化为 Swap
echo "⚙️ 正在格式化为 Swap 分区..."
mkswap "$TARGET_SWAP" >/dev/null

# 5. 启用 Swap
echo "🔛 正在启用新 Swap..."
swapon "$TARGET_SWAP"

# 6. 设置永久挂载
echo "💾 正在配置开机自动挂载..."
echo "$TARGET_SWAP none swap sw 0 0" >> /etc/fstab

# 7. 优化 Swappiness
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
    echo "vm.swappiness=10" >> /etc/sysctl.conf
else
    sed -i 's/vm.swappiness=.*/vm.swappiness=10/g' /etc/sysctl.conf
fi
sysctl -p >/dev/null

echo "----------------------------------------"
echo "🎉 虚拟内存重新配置完成！当前状态："
echo "----------------------------------------"
free -h
