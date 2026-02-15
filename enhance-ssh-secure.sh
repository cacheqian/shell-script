#!/bin/bash

# =========================================================
# Ubuntu 24.04 SSH 安全加固自动化脚本
# 功能：修改端口 | 部署公钥 | 禁用密码 | 适配 Systemd Socket
# =========================================================

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 初始化变量
BACKUP_SUFFIX="$(date +%F_%T)"
BACKUP_FILE="/etc/ssh/sshd_config.bak.${BACKUP_SUFFIX}"
CONFIG_FILE="/etc/ssh/sshd_config"

# 检查 Root 权限
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}错误：请使用 root 权限或 sudo 运行此脚本。${NC}"
  exit 1
fi

echo -e "${GREEN}=== 开始执行 SSH 安全加固流程 ===${NC}"

# ----------------------------
# 1. 信息收集
# ----------------------------
while true; do
    read -p "请输入新的 SSH 端口号 (建议 1024-65535，默认 22): " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}
    if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1 ] && [ "$SSH_PORT" -le 65535 ]; then
        echo -e "目标端口: ${YELLOW}$SSH_PORT${NC}"
        break
    else
        echo -e "${RED}端口无效，请重新输入。${NC}"
    fi
done

echo ""
echo "请粘贴公钥字符串 (以 ssh-rsa 或 ssh-ed25519 开头):"
read -r PUBLIC_KEY

if [ -z "$PUBLIC_KEY" ]; then
    echo -e "${RED}错误：公钥不能为空。${NC}"
    exit 1
fi

# ----------------------------
# 2. 环境备份与密钥部署
# ----------------------------
echo -e "${BLUE}[+] 正在备份配置文件...${NC}"
cp "$CONFIG_FILE" "$BACKUP_FILE"

echo -e "${BLUE}[+] 正在部署 SSH 公钥...${NC}"
USER_HOME=$(eval echo ~$USER)
SSH_DIR="$USER_HOME/.ssh"
AUTH_FILE="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if grep -qF "$PUBLIC_KEY" "$AUTH_FILE" 2>/dev/null; then
    echo " -> 公钥已存在，跳过写入。"
else
    echo "$PUBLIC_KEY" >> "$AUTH_FILE"
    echo " -> 公钥写入完成。"
fi
chmod 600 "$AUTH_FILE"
chown -R $USER:$USER "$SSH_DIR"

# ----------------------------
# 3. 核心配置修改
# ----------------------------
echo -e "${BLUE}[+] 正在优化 SSHD 配置...${NC}"

# 辅助函数
update_config() {
    local param=$1
    local value=$2
    if grep -q "^$param" "$CONFIG_FILE"; then
        sed -i "s|^$param.*|$param $value|" "$CONFIG_FILE"
    elif grep -q "^#$param" "$CONFIG_FILE"; then
        sed -i "s|^#$param.*|$param $value|" "$CONFIG_FILE"
    else
        echo "$param $value" >> "$CONFIG_FILE"
    fi
}

# 屏蔽 Include 以防止 Cloud-init 覆盖配置
sed -i 's|^Include /etc/ssh/sshd_config.d|#Include /etc/ssh/sshd_config.d|g' "$CONFIG_FILE"

# 修改端口
sed -i 's/^Port /#Port /g' "$CONFIG_FILE"
echo "Port $SSH_PORT" >> "$CONFIG_FILE"

# 安全策略配置
update_config "PasswordAuthentication" "no"
update_config "KbdInteractiveAuthentication" "no"
update_config "PubkeyAuthentication" "yes"
update_config "PermitRootLogin" "prohibit-password"
update_config "UsePAM" "yes"

# ----------------------------
# 4. Ubuntu 24.04 特性适配
# ----------------------------
echo -e "${BLUE}[+] 适配 Systemd 服务模式...${NC}"

# 禁用 ssh.socket (按需激活模式)，转为 ssh.service (常驻模式)
# 这解决了非 22 端口监听失败的问题
if systemctl is-active --quiet ssh.socket; then
    systemctl stop ssh.socket
    systemctl disable ssh.socket
fi
systemctl enable ssh.service >/dev/null 2>&1

# ----------------------------
# 5. 运行时环境修复
# ----------------------------
# 确保特权分离目录存在 (OpenSSH 运行依赖)
if [ ! -d "/run/sshd" ]; then
    mkdir -p /run/sshd
    chmod 0755 /run/sshd
fi

# ----------------------------
# 6. 防火墙检查与服务重启
# ----------------------------
echo -e "${BLUE}[+] 检查系统防火墙...${NC}"

FIREWALL_WARN=0
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "active"; then
         echo -e "${YELLOW}警告：UFW 防火墙已开启。请务必执行: ufw allow $SSH_PORT/tcp${NC}"
         FIREWALL_WARN=1
    fi
fi

if [ $FIREWALL_WARN -eq 0 ]; then
    echo " -> 未检测到活跃的系统防火墙阻断。"
fi

echo -e "${RED}>>> 务必确认云服务器安全组已放行 TCP 端口: $SSH_PORT <<<${NC}"

echo -e "${BLUE}[+] 验证配置并重启服务...${NC}"
systemctl daemon-reload

if sshd -t; then
    echo -e "${GREEN}配置验证通过。${NC}"
    systemctl restart ssh

    sleep 1
    if ss -tulpn | grep -q ":$SSH_PORT "; then
         echo ""
         echo -e "${GREEN}✅ 加固完成！${NC}"
         echo -e "   新端口: ${YELLOW}$SSH_PORT${NC}"
         echo -e "   登录方式: ${YELLOW}仅密钥${NC}"
         echo -e "   请保持当前窗口，新开一个终端进行连接测试。"
    else
         echo -e "${RED}警告：服务已重启，但未检测到端口监听。请手动排查。${NC}"
    fi
else
    echo -e "${RED}配置验证失败！${NC}"
    echo "正在回滚配置..."
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    # 恢复 Include 注释
    sed -i 's|^#Include /etc/ssh/sshd_config.d|Include /etc/ssh/sshd_config.d|g' "$CONFIG_FILE"
    echo "已恢复至原有状态。"
fi
