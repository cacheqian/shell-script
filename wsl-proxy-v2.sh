#!/bin/bash
# ============================================
# WSL 代理配置脚本
# 功能：配置 Shell/Git/APT 代理 + 系统更新
# 用法：./wsl-proxy.sh [端口|--remove|-r]
# ============================================
set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置块标记（用于 sed 定位）
MARKER_BEGIN="# >>> WSL PROXY CONFIG"
MARKER_END="# <<< WSL PROXY CONFIG"

# ============================================
# 参数解析
# ============================================
if [[ "${1:-}" == "--remove" || "${1:-}" == "-r" ]]; then
    MODE="remove"
    PROXY_PORT=""
elif [[ -n "${1:-}" ]]; then
    MODE="install"
    PROXY_PORT="$1"
else
    MODE="install"
    PROXY_PORT=""
fi

# ============================================
# 清理函数
# ============================================
remove_config() {
    local changed=0

    # 清理 ~/.bashrc
    if grep -qF "$MARKER_BEGIN" ~/.bashrc 2>/dev/null; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" ~/.bashrc
        echo -e "${GREEN}✓${NC} 已清理 ~/.bashrc 代理配置"
        changed=1
    fi

    # 清理 APT 代理
    if [[ -f /etc/apt/apt.conf.d/proxy.conf ]]; then
        sudo rm -f /etc/apt/apt.conf.d/proxy.conf
        echo -e "${GREEN}✓${NC} 已清理 APT 代理配置"
        changed=1
    fi

    # 清理 Git 代理
    if git config --global http.proxy &>/dev/null; then
        git config --global --unset http.proxy 2>/dev/null || true
        git config --global --unset https.proxy 2>/dev/null || true
        echo -e "${GREEN}✓${NC} 已清理 Git 代理配置"
        changed=1
    fi

    if [[ $changed -eq 0 ]]; then
        echo -e "${YELLOW}未找到代理配置，无需清理${NC}"
    else
        echo ""
        echo -e "${YELLOW}提示: 请重新打开终端或执行 source ~/.bashrc 使清理生效${NC}"
    fi
    exit 0
}

# ============================================
# 获取代理端口
# ============================================
if [[ "$MODE" == "remove" ]]; then
    remove_config
fi

if [[ -z "$PROXY_PORT" ]]; then
    echo -en "${YELLOW}请输入代理端口 (默认 7890):${NC} "
    read -r PROXY_PORT
    PROXY_PORT="${PROXY_PORT:-7890}"
fi

# 端口合法性校验
if ! [[ "$PROXY_PORT" =~ ^[0-9]+$ ]] || [[ "$PROXY_PORT" -lt 1 ]] || [[ "$PROXY_PORT" -gt 65535 ]]; then
    echo -e "${RED}错误: 无效的端口号: $PROXY_PORT${NC}"
    exit 1
fi

echo -e "使用端口: ${GREEN}${PROXY_PORT}${NC}"
echo ""

# ============================================
# 检测代理端口连通性 (WSL2 镜像网络)
# ============================================
echo -e "${BLUE}[检测]${NC} 测试 127.0.0.1:${PROXY_PORT} 连通性..."
if timeout 2 bash -c "</dev/tcp/127.0.0.1/${PROXY_PORT}" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} 代理端口可连通"
else
    echo -e "${YELLOW}⚠ 127.0.0.1:${PROXY_PORT} 当前无响应，请确认宿主机代理已启动${NC}"
    echo -en "${YELLOW}是否继续配置? [y/N]:${NC} "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
fi
echo ""

# ============================================
# 步骤1：配置 Shell 代理 (~/.bashrc)
# ============================================
echo -e "${YELLOW}[1/5] 配置 Shell 代理...${NC}"

# 先删除旧配置块，避免重复追加
if grep -qF "$MARKER_BEGIN" ~/.bashrc 2>/dev/null; then
    sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" ~/.bashrc
fi

cat << EOF >> ~/.bashrc
$MARKER_BEGIN
PROXY_PORT="${PROXY_PORT}"
PROXY_URL="http://127.0.0.1:\${PROXY_PORT}"

# 开启代理
function proxy() {
    export http_proxy="\$PROXY_URL"
    export https_proxy="\$PROXY_URL"
    export HTTP_PROXY="\$PROXY_URL"
    export HTTPS_PROXY="\$PROXY_URL"
    export all_proxy="socks5://127.0.0.1:\${PROXY_PORT}"
    export no_proxy="localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"
    export NO_PROXY="\$no_proxy"
    echo -e "Proxy set to \033[32m\$PROXY_URL\033[0m"
}

# 关闭代理
function noproxy() {
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy no_proxy NO_PROXY
    echo -e "Proxy \033[31mremoved\033[0m"
}

# 查看当前代理状态
function proxystat() {
    if [[ -n "\${http_proxy:-}" ]]; then
        echo -e "Current proxy: \033[32m\$http_proxy\033[0m"
    else
        echo -e "Proxy is \033[31mOFF\033[0m"
    fi
}

# 默认开启代理（如需默认关闭，注释掉下面这一行）
proxy
$MARKER_END
EOF

echo -e "${GREEN}✓${NC} Shell 代理配置完成"

# ============================================
# 步骤2：配置 Git 代理
# ============================================
echo -e "${YELLOW}[2/5] 配置 Git 代理...${NC}"
git config --global http.proxy "http://127.0.0.1:${PROXY_PORT}" 2>/dev/null || true
git config --global https.proxy "http://127.0.0.1:${PROXY_PORT}" 2>/dev/null || true
echo -e "${GREEN}✓${NC} Git 代理配置完成"

# ============================================
# 步骤3：配置 APT 代理
# ============================================
echo -e "${YELLOW}[3/5] 配置 APT 代理...${NC}"
sudo tee /etc/apt/apt.conf.d/proxy.conf > /dev/null << EOF
Acquire::http::Proxy "http://127.0.0.1:${PROXY_PORT}";
Acquire::https::Proxy "http://127.0.0.1:${PROXY_PORT}";
EOF
echo -e "${GREEN}✓${NC} APT 代理配置完成"

# ============================================
# 步骤4：可选 - 替换 APT 源为阿里云镜像
# ============================================
echo -en "${YELLOW}[4/5] 是否将 APT 源替换为阿里云镜像? [y/N]:${NC} "
read -r mirror_confirm
if [[ "$mirror_confirm" =~ ^[Yy]$ ]]; then
    # 自动检测系统版本代号
    CODENAME=""
    if command -v lsb_release &>/dev/null; then
        CODENAME=$(lsb_release -cs)
    elif [[ -f /etc/os-release ]]; then
        CODENAME=$(source /etc/os-release && echo "$VERSION_CODENAME")
    fi

    if [[ -z "$CODENAME" ]]; then
        echo -e "${RED}✗ 无法检测系统版本，跳过换源${NC}"
    else
        echo -e "${BLUE}  检测到系统版本代号: ${CODENAME}${NC}"

        # Ubuntu 24.04+ 使用 /etc/apt/sources.list.d/ubuntu.sources (DEB822 格式)
        if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
            # 备份到 /root/ 避免 apt 扫描报错
            sudo cp /etc/apt/sources.list.d/ubuntu.sources "/root/ubuntu.sources.bak.$(date +%Y%m%d_%H%M%S)"
            sudo sed -i 's|archive.ubuntu.com|mirrors.aliyun.com|g' /etc/apt/sources.list.d/ubuntu.sources
            sudo sed -i 's|security.ubuntu.com|mirrors.aliyun.com|g' /etc/apt/sources.list.d/ubuntu.sources
            echo -e "${GREEN}✓${NC} 已替换 ubuntu.sources"

            # 清空 /etc/apt/sources.list 中与官方源重复的行，避免 "configured multiple times" 警告
            if [[ -f /etc/apt/sources.list ]]; then
                sudo sed -i '/^deb .*ubuntu\.com/d' /etc/apt/sources.list
                sudo sed -i '/^deb .*mirrors\.aliyun\.com/d' /etc/apt/sources.list
                # 如果文件变空或只剩空行/注释，追加一个提示
                if ! grep -qE '^deb ' /etc/apt/sources.list 2>/dev/null; then
                    sudo tee /etc/apt/sources.list >/dev/null << EOF
# 系统默认源已迁移至 /etc/apt/sources.list.d/ubuntu.sources
# 如需添加第三方源，请在此文件追加
EOF
                fi
            fi
        else
            # 旧版本（24.04 之前）：直接覆盖 /etc/apt/sources.list
            BACKUP_FILE="/root/sources.list.bak.$(date +%Y%m%d_%H%M%S)"
            sudo cp /etc/apt/sources.list "$BACKUP_FILE"

            # 保留原文件中非 Ubuntu 官方的第三方源（PPA 等）
            EXTRA_LINES=$(grep -vE '^#|^ *$' /etc/apt/sources.list 2>/dev/null | grep -vE 'ubuntu\.com|mirrors\.aliyun\.com' || true)

            # 写入对应版本的阿里云标准源
            sudo tee /etc/apt/sources.list >/dev/null << EOF
deb https://mirrors.aliyun.com/ubuntu/ ${CODENAME} main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ ${CODENAME} main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ ${CODENAME}-updates main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ ${CODENAME}-updates main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ ${CODENAME}-backports main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ ${CODENAME}-backports main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ ${CODENAME}-security main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ ${CODENAME}-security main restricted universe multiverse
EOF

            if [[ -n "$EXTRA_LINES" ]]; then
                {
                    echo ""
                    echo "# 保留的原始第三方源"
                    echo "$EXTRA_LINES"
                } | sudo tee -a /etc/apt/sources.list >/dev/null
            fi

            echo -e "${GREEN}✓${NC} 已替换为阿里云镜像 (备份: $BACKUP_FILE)"
        fi

        # 处理 /etc/apt/sources.list.d/ 下的 .list 文件（第三方 .list 中的官方源）
        for f in /etc/apt/sources.list.d/*.list; do
            [[ -f "$f" ]] || continue
            if grep -qE 'archive\.ubuntu\.com|security\.ubuntu\.com' "$f" 2>/dev/null; then
                sudo cp "$f" "/root/$(basename "$f").bak.$(date +%Y%m%d_%H%M%S)"
                sudo sed -i 's|archive.ubuntu.com|mirrors.aliyun.com|g' "$f"
                sudo sed -i 's|security.ubuntu.com|mirrors.aliyun.com|g' "$f"
                echo -e "${GREEN}✓${NC} 已替换 $(basename "$f")"
            fi
        done

        # 清理之前脚本产生的无效备份（避免 apt 报 "invalid filename extension"）
        for bak in /etc/apt/sources.list.d/*.bak.*; do
            [[ -f "$bak" ]] || continue
            sudo rm -f "$bak"
        done

        # 已使用国内镜像，APT 无需再走代理
        if [[ -f /etc/apt/apt.conf.d/proxy.conf ]]; then
            sudo rm -f /etc/apt/apt.conf.d/proxy.conf
            echo -e "${GREEN}✓${NC} 已清理 APT 代理配置（国内镜像无需代理）"
        fi
    fi
else
    echo -e "${YELLOW}↷ 跳过换源${NC}"
fi
echo ""

# ============================================
# 步骤5：更新系统
# ============================================
echo -e "${YELLOW}[5/5] 更新系统...${NC}"
sudo apt update && sudo apt upgrade -y
echo -e "${GREEN}✓${NC} 系统更新完成"

# ============================================
# 完成
# ============================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✓ WSL 代理配置完成！${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "代理端口: ${YELLOW}${PROXY_PORT}${NC}"
echo ""
echo -e "使用方法："
echo -e "  ${YELLOW}proxy${NC}     - 开启代理"
echo -e "  ${YELLOW}noproxy${NC}   - 关闭代理"
echo -e "  ${YELLOW}proxystat${NC} - 查看代理状态"
echo ""
echo -e "卸载命令："
echo -e "  ${YELLOW}./wsl-proxy.sh --remove${NC}"
echo ""
echo -e "${YELLOW}提示: 请重新打开终端或执行 source ~/.bashrc 使配置生效${NC}"
