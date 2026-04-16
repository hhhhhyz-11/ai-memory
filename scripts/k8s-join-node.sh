#!/bin/bash
# K8s 节点加入集群完整脚本
# 用法: bash k8s-join-node.sh <主节点IP> <JOIN_TOKEN> <CA_HASH>
# 示例: bash k8s-join-node.sh 192.168.1.100 abc.def.xxx sha256:xxxxx

set -e

# ========== 参数检查 ==========
if [ $# -ne 3 ]; then
    echo "用法: $0 <主节点IP> <JOIN_TOKEN> <CA_HASH>"
    echo "示例: $0 192.168.1.100 abc.def.xxx sha256:xxxxx"
    echo ""
    echo "获取方式（在主节点上执行）:"
    echo "  kubeadm token create --print-join-command"
    exit 1
fi

MASTER_IP=$1
JOIN_TOKEN=$2
CA_HASH=$3

echo "==== K8s 节点初始化脚本 ===="
echo "主节点: $MASTER_IP"

# ========== 1. 设置 hostname ==========
echo ""
echo "==== 1. 设置 hostname ===="
hostnamectl set-hostname node1
if grep -q "127.0.1.1" /etc/hosts; then
    sed -i "s/^127.0.1.1.*/127.0.1.1 node1/" /etc/hosts
else
    echo "127.0.1.1 node1" >> /etc/hosts
fi

# ========== 2. 原有系统优化（你已经做过的部分） ==========
echo ""
echo "==== 2. 系统基础优化（跳过，已执行） ===="
echo "跳过，如果需要请单独执行 youhua.sh"

# ========== 3. K8s 必需内核模块 ==========
echo ""
echo "==== 3. 加载 K8s 内核模块 ===="
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
nf_conntrack
EOF
modprobe overlay || echo "overlay 模块加载失败"
modprobe br_netfilter || echo "br_netfilter 模块加载失败"

# ========== 4. K8s 网络内核参数 ==========
echo ""
echo "==== 4. 配置 K8s 网络内核参数 ===="
cat >> /etc/sysctl.d/99-optimization.conf <<EOF

# ===== K8s 网络必须参数 =====
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1

# 关闭 rp_filter（容器网络需要）
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0

# iptables 规则可见性
net.netfilter.nf_conntrack_max = 1000000
EOF
sysctl -p /etc/sysctl.d/99-optimization.conf > /dev/null 2>&1 || true

# ========== 5. 关闭 SELinux ==========
echo ""
echo "==== 5. 关闭 SELinux ===="
setenforce 0 2>/dev/null || true
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config 2>/dev/null || true

# ========== 6. 关闭防火墙 ==========
echo ""
echo "==== 6. 关闭防火墙 ===="
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
echo "防火墙已关闭"

# ========== 7. 确认 swap 已关闭 ==========
echo ""
echo "==== 7. 确认 swap 已关闭 ===="
SWAP_COUNT=$(cat /proc/swaps | grep -v "Filename" | wc -l)
if [ "$SWAP_COUNT" -gt 0 ]; then
    echo "检测到 swap 已开启，关闭中..."
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab
fi
echo "swap 状态:"
grep -v "Filename" /proc/swaps || echo "无 swap"

# ========== 8. 安装 containerd ==========
echo ""
echo "==== 8. 安装 containerd ===="
# 判断是 CentOS/RHEL 还是 Ubuntu
if command -v yum &>/dev/null; then
    yum install -y containerd
elif command -v apt-get &>/dev/null; then
    apt-get update -y
    apt-get install -y containerd
fi

# ========== 9. 配置 containerd ==========
echo ""
echo "==== 9. 配置 containerd ===="
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# 修改为 systemd cgroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 修改 pause 镜像为国内源（K8s 1.24+）
sed -i 's|k8s.gcr.io/pause|registry.aliyuncs.com/google_containers|g' /etc/containerd/config.toml

# 启用 containerd
systemctl enable containerd
systemctl restart containerd
echo "containerd 状态:"
systemctl is-active containerd

# ========== 10. 安装 Kubernetes 组件 ==========
echo ""
echo "==== 10. 安装 kubelet kubeadm kubectl ===="
# 阿里云 K8s 源
cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
EOF

# Ubuntu 源
if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
    curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 2>/dev/null || true
    add-apt-repository "deb https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main" 2>/dev/null || true
fi

# 安装（指定版本避免升级）
K8S_VERSION=$(yum list kubeadm --showduplicates 2>/dev/null | sort -r | head -1 | awk '{print $2}' | cut -d: -f2 || echo "1.28.2")
yum install -y kubelet-${K8S_VERSION} kubeadm-${K8S_VERSION} kubectl-${K8S_VERSION} --disableexcludes=kubernetes 2>/dev/null || \
apt-get install -y kubelet kubeadm kubectl 2>/dev/null || true

systemctl enable kubelet

# ========== 11. 加入集群 ==========
echo ""
echo "==== 11. 加入 K8s 集群 ===="
JOIN_CMD="kubeadm join ${MASTER_IP}:6443 --token ${JOIN_TOKEN} --discovery-token-ca-cert-hash ${CA_HASH}"
echo "执行: $JOIN_CMD"
$JOIN_CMD

echo ""
echo "==== 加入完成 ===="
echo "在主节点执行以下命令确认节点状态:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
