#!/bin/bash
# ============================================
# WSL 代理配置脚本
# 功能：配置代理 + 系统更新
# ============================================
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# ============================================
# 获取代理端口
# ============================================
echo -e "${YELLOW}请输入代理端口 (默认 7890):${NC} "
read -r PROXY_PORT
PROXY_PORT="${PROXY_PORT:-7890}"
echo -e "使用端口: ${GREEN}${PROXY_PORT}${NC}"
echo ""

# ============================================
# 步骤1：配置 Shell 代理 (~/.bashrc)
# ============================================
echo -e "${YELLOW}[1/3] 配置 Shell 代理...${NC}"

if grep -q "# === Smart Proxy Aliases ===" ~/.bashrc 2>/dev/null; then
    echo -e "${YELLOW}代理配置已存在，跳过...${NC}"
else
    cat << EOF >> ~/.bashrc
# ================== Smart Proxy Aliases ==================
PROXY_PORT="${PROXY_PORT}"
PROXY_URL="http://127.0.0.1:\${PROXY_PORT}"

# 开启代理
function proxy() {
    export http_proxy="\$PROXY_URL"
    export https_proxy="\$PROXY_URL"
    export all_proxy="socks5://127.0.0.1:\${PROXY_PORT}"
    export no_proxy="localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"
    echo -e "🚀 Proxy set to \033[32m\$PROXY_URL\033[0m"
}

# 关闭代理
function noproxy() {
    unset http_proxy https_proxy all_proxy no_proxy PROXY_URL
    echo -e "🛑 Proxy \033[31mremoved\033[0m"
}

# 查看当前代理状态
function proxystat() {
    if [ -n "\$http_proxy" ]; then
        echo -e "📡 Current proxy: \033[32m\$http_proxy\033[0m"
    else
        echo -e "📡 Proxy is \033[31mOFF\033[0m"
    fi
}

# 默认开启代理（如需默认关闭，注释掉下面这一行）
proxy
# =========================================================
EOF
    echo -e "${GREEN}✓ Shell 代理配置完成${NC}"
fi

# ============================================
# 步骤2：配置 APT 代理
# ============================================
echo -e "${YELLOW}[2/3] 配置 APT 代理...${NC}"
sudo tee /etc/apt/apt.conf.d/proxy.conf > /dev/null << EOF
Acquire::http::Proxy "http://127.0.0.1:${PROXY_PORT}";
Acquire::https::Proxy "http://127.0.0.1:${PROXY_PORT}";
EOF
echo -e "${GREEN}✓ APT 代理配置完成${NC}"

# ============================================
# 步骤3：更新系统
# ============================================
echo -e "${YELLOW}[3/3] 更新系统...${NC}"
sudo apt update && sudo apt upgrade -y
echo -e "${GREEN}✓ 系统更新完成${NC}"

# ============================================
# 完成
# ============================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✓ WSL 代理配置完成！${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "使用方法："
echo -e "  ${YELLOW}proxy${NC}     - 开启代理"
echo -e "  ${YELLOW}noproxy${NC}   - 关闭代理"
echo -e "  ${YELLOW}proxystat${NC} - 查看代理状态"
echo ""
echo -e "代理端口: ${YELLOW}${PROXY_PORT}${NC}"
echo ""
echo -e "${YELLOW}提示: 请重新打开终端或执行 source ~/.bashrc 使配置生效${NC}"
