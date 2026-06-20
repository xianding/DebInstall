#!/bin/bash
if [ "$EUID" -ne 0 ]; then
 echo "❌ 请使用 sudo 或 root 权限运行此脚本！"
 exit 1
fi
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))
echo "=================================================="
echo "ℹ️  当前系统检测到物理内存: ${TOTAL_MEM_MB} MB"
echo "=================================================="
if [ "$TOTAL_MEM_MB" -lt 2000 ]; then
 echo "🚀 已匹配 [小于 2G 内存] 极致内核与网络方案"
 FILE_MAX=65535
 MAX_BUF=33554432
 DEF_BUF=131072
 TCP_MEM="65536 98304 147456"
 CONN_QUEUE=4096
 DIRTY_BACKGROUND=5
 DIRTY_RATIO=10
elif [ "$TOTAL_MEM_MB" -ge 2000 ] && [ "$TOTAL_MEM_MB" -lt 4500 ]; then
 echo "🚀 已匹配 [2G - 4G 内存] 黄金内核与网络方案"
 FILE_MAX=1048576
 MAX_BUF=67108864
 DEF_BUF=262144
 TCP_MEM="131072 262144 524288"
 CONN_QUEUE=16384
 DIRTY_BACKGROUND=10
 DIRTY_RATIO=20
elif [ "$TOTAL_MEM_MB" -ge 4500 ] && [ "$TOTAL_MEM_MB" -lt 6500 ]; then
 echo "🚀 已匹配 [4G - 6G 内存] 全面释放内核方案"
 FILE_MAX=2097152
 MAX_BUF=67108864
 DEF_BUF=262144
 TCP_MEM="131072 393216 655360"
 CONN_QUEUE=32768
 DIRTY_BACKGROUND=10
 DIRTY_RATIO=20
else
 echo "🚀 已匹配 [大于 6G 内存] 终极全性能内核方案"
 FILE_MAX=4194304
 MAX_BUF=134217728
 DEF_BUF=524288
 TCP_MEM="196608 393216 786432"
 CONN_QUEUE=65535
 DIRTY_BACKGROUND=10
 DIRTY_RATIO=20
fi
cp /etc/sysctl.conf /etc/sysctl.conf.bak.$(date +%F_%T)
echo "💾 原配置已安全备份。"
printf "# =================================================================
# 1. 深度系统内核与虚拟内存管理优化 (基于内存总量: ${TOTAL_MEM_MB}MB)
# =================================================================
vm.swappiness = 10
vm.vfs_cache_pressure = 50
fs.file-max = ${FILE_MAX}
vm.dirty_background_ratio = ${DIRTY_BACKGROUND}
vm.dirty_ratio = ${DIRTY_RATIO}
vm.panic_on_oom = 0
kernel.panic = 10
# =================================================================
# 2. 网络拥塞控制与握手加速
# =================================================================
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
# =================================================================
# 3. 动态网络缓冲区调整
# =================================================================
net.core.rmem_max = ${MAX_BUF}
net.core.wmem_max = ${MAX_BUF}
net.ipv4.tcp_rmem = 4096 ${DEF_BUF} ${MAX_BUF}
net.ipv4.tcp_wmem = 4096 ${DEF_BUF} ${MAX_BUF}
net.ipv4.tcp_moderate_rcvbuf = 1
# =================================================================
# 4. TCP 全局内存安全锁
# =================================================================
net.ipv4.tcp_mem = ${TCP_MEM}
# =================================================================
# 5. 延迟、断流与网络队列防死锁优化
# =================================================================
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_retries2 = 8
net.core.somaxconn = ${CONN_QUEUE}
net.ipv4.tcp_max_syn_backlog = \$((CONN_QUEUE / 2))
net.core.netdev_max_backlog = \$((CONN_QUEUE / 2))
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_syncookies = 1
" > /etc/sysctl.conf
echo "📝 整合版内核参数写入完成。"
echo "🔄 正在刷新内核参数..."
sysctl -p
echo "=================================================="
echo "✅ 深度双重优化成功！您的内核机制与网络协议栈已达到最佳配合！"
echo "=================================================="
