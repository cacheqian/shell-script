#!/usr/bin/env bash
# WSL2 代理配置脚本 v3
#
# 适用环境：Ubuntu 24.04 + WSL2 mirrored networking
# 代理：mixed proxy，127.0.0.1:7890
#
# 功能：
#   - 配置 Shell 和 Git 代理
#   - 手动 proxy / noproxy 开关，不自动启用
#   - 将 Ubuntu 官方 APT 源切换为阿里云镜像
#   - APT 换源后直连，不使用代理
#   - 仅执行 apt update，不自动升级系统
#   - 关闭 Windows 磁盘自动挂载，并将指定盘符只读挂载
#
# 用法：./wsl-proxy-v3.sh

set -euo pipefail

readonly SCRIPT_VERSION="3.0"
readonly MARKER_BEGIN="# >>> WSL PROXY CONFIG V3"
readonly MARKER_END="# <<< WSL PROXY CONFIG V3"
readonly BASHRC="${HOME}/.bashrc"
readonly PROXY_PORT="7890"
readonly DRIVE_UPPER="C"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "$*"; }
die() { log "${RED}错误:${NC} $*" >&2; exit 1; }

require_commands() {
    local command_name
    for command_name in sed grep python3 timeout mountpoint mount umount sudo; do
        command -v "$command_name" >/dev/null 2>&1 || die "缺少命令: $command_name"
    done
}

check_environment() {
    local os_id=""
    local version_id=""

    if ! grep -qiE 'microsoft-standard-wsl2|wsl2' /proc/version /proc/sys/kernel/osrelease 2>/dev/null; then
        die "未检测到 WSL 环境；此脚本只能在 WSL2 中执行"
    fi

    [[ -f /etc/os-release ]] || die "找不到 /etc/os-release，无法确认 Linux 发行版"
    # shellcheck disable=SC1091
    source /etc/os-release
    os_id="${ID:-}"
    version_id="${VERSION_ID:-}"

    [[ "$os_id" == "ubuntu" ]] || die "仅支持 Ubuntu，检测到: ${os_id:-未知系统}"
    [[ "$version_id" == "24.04" ]] || die "仅支持 Ubuntu 24.04，检测到: ${version_id:-未知版本}"

    log "${GREEN}✓${NC} 环境检查通过：WSL2 + Ubuntu ${version_id}"
}

install_bashrc_block() {
    touch "$BASHRC"

    cat >> "$BASHRC" <<EOF
$MARKER_BEGIN
PROXY_PORT="${PROXY_PORT}"
PROXY_HTTP_URL="http://127.0.0.1:\${PROXY_PORT}"
PROXY_SOCKS_URL="socks5h://127.0.0.1:\${PROXY_PORT}"

# 开启 mixed 代理
proxy() {
    export http_proxy="\$PROXY_HTTP_URL"
    export https_proxy="\$PROXY_HTTP_URL"
    export HTTP_PROXY="\$PROXY_HTTP_URL"
    export HTTPS_PROXY="\$PROXY_HTTP_URL"
    export all_proxy="\$PROXY_SOCKS_URL"
    export ALL_PROXY="\$PROXY_SOCKS_URL"
    export no_proxy="localhost,127.0.0.1,::1"
    export NO_PROXY="\$no_proxy"
    echo -e "Proxy set to \\033[32m\$PROXY_HTTP_URL\\033[0m"
}

# 关闭代理
noproxy() {
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY no_proxy NO_PROXY
    echo -e "Proxy \\033[31mremoved\\033[0m"
}

# 查看代理状态
proxystat() {
    if [[ -n "\${http_proxy:-}" ]]; then
        echo -e "Proxy is \\033[32mON\\033[0m: \$http_proxy"
    else
        echo -e "Proxy is \\033[31mOFF\\033[0m"
    fi
}
$MARKER_END
EOF
    log "${GREEN}✓${NC} Shell 代理配置完成（不会自动启用）"
}

configure_git_proxy() {
    git config --global http.proxy "http://127.0.0.1:${PROXY_PORT}"
    git config --global https.proxy "http://127.0.0.1:${PROXY_PORT}"
    log "${GREEN}✓${NC} Git 代理配置完成"
}

ensure_git() {
    if command -v git >/dev/null 2>&1; then
        return 0
    fi

    log "${YELLOW}[Git]${NC} 未检测到 Git，正在从阿里云 APT 源安装..."
    sudo apt install -y git
    command -v git >/dev/null 2>&1 || die "Git 安装失败"
    log "${GREEN}✓${NC} Git 安装完成"
}

configure_wsl_mount() {
    local drive_upper="$DRIVE_UPPER"
    local drive_lower="${drive_upper,,}"
    local wsl_conf="/etc/wsl.conf"
    local fstab="/etc/fstab"
    local mount_dir="/mnt/${drive_lower}"
    local timestamp="$(date +%Y%m%d-%H%M%S)"
    local wsl_backup="/etc/wsl.conf.bak.${timestamp}"
    local fstab_backup="/etc/fstab.bak.${timestamp}"

    [[ "$EUID" -ne 0 ]] || die "请以普通用户执行脚本，脚本会在需要时调用 sudo"
    [[ "$drive_upper" =~ ^[A-Z]$ ]] || die "盘符必须是单个英文字母，例如 C"

    sudo cp -a "$wsl_conf" "$wsl_backup" 2>/dev/null || true
    sudo cp -a "$fstab" "$fstab_backup" 2>/dev/null || true

    # 只替换 [automount] 段，保留 wsl.conf 中已有的其他配置和注释。
    sudo python3 - "$wsl_conf" <<'PY'
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()
except FileNotFoundError:
    lines = []

out = []
in_automount = False
for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        in_automount = stripped.lower() == "[automount]"
    if in_automount:
        continue
    out.append(line)

while out and not out[-1].strip():
    out.pop()
if out:
    out.append("\n")
out.extend([
    "[automount]\n",
    "enabled=false\n",
    "mountFsTab=true\n",
])

with open(path, "w", encoding="utf-8") as f:
    f.writelines(out)
PY
    log "${GREEN}✓${NC} 已配置 WSL：关闭 Windows 磁盘自动挂载"

    sudo touch "$fstab"
    # 只删除同一挂载点的旧条目，保留其他 fstab 配置。
    sudo sed -i -E "\\|[[:space:]]${mount_dir}[[:space:]]|d" "$fstab"
    sudo mkdir -p "$mount_dir"
    echo "${drive_upper}: ${mount_dir} drvfs defaults,ro 0 0" | sudo tee -a "$fstab" >/dev/null
    log "${GREEN}✓${NC} 已配置 ${drive_upper}: 只读挂载到 ${mount_dir}"

    # 尝试立即重新挂载；如果被占用，重启 WSL 后自动生效。
    if mountpoint -q "$mount_dir" 2>/dev/null; then
        if sudo umount "$mount_dir" 2>/dev/null && sudo mount "$mount_dir" 2>/dev/null; then
            log "${GREEN}✓${NC} ${mount_dir} 已立即重新挂载为只读"
        else
            log "${YELLOW}⚠${NC} ${mount_dir} 当前被占用，修改将在 wsl --shutdown 后生效"
        fi
    else
        sudo mount "$mount_dir" 2>/dev/null || true
    fi

    log "${BLUE}备份:${NC} ${wsl_backup} 和 ${fstab_backup}（如果原文件存在）"
    log "${YELLOW}提示:${NC} 请在 Windows PowerShell 执行 wsl --shutdown，然后重新进入 WSL 以完全生效。"
}

switch_ubuntu_sources() {
    local os_id="" codename="" source_file="/etc/apt/sources.list.d/ubuntu.sources"
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        os_id="${ID:-}"
        codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
    fi

    [[ "$os_id" == "ubuntu" ]] || die "此脚本仅支持 Ubuntu，检测到: ${os_id:-未知系统}"
    [[ -n "$codename" ]] || die "无法检测 Ubuntu 版本代号"
    [[ -f "$source_file" ]] || die "找不到 Ubuntu 24.04 软件源文件: $source_file"

    local backup_file="/root/ubuntu.sources.bak.$(date +%Y%m%d_%H%M%S)"
    if grep -qE 'archive\.ubuntu\.com|security\.ubuntu\.com' "$source_file"; then
        sudo cp -p "$source_file" "$backup_file"
        sudo sed -i \
            -e 's|archive\.ubuntu\.com|mirrors.aliyun.com|g' \
            -e 's|security\.ubuntu\.com|mirrors.aliyun.com|g' \
            "$source_file"
        log "${GREEN}✓${NC} Ubuntu APT 源已切换为阿里云（备份: $backup_file）"
    elif grep -qF 'mirrors.aliyun.com/ubuntu' "$source_file"; then
        log "${GREEN}✓${NC} Ubuntu APT 源已经是阿里云，无需修改"
    else
        log "${YELLOW}⚠${NC} 未发现 Ubuntu 官方源地址，保留现有配置: $source_file"
    fi
}

check_proxy_port() {
    log "${BLUE}[检测]${NC} 测试 127.0.0.1:${PROXY_PORT} 端口..."
    if timeout 2 bash -c "</dev/tcp/127.0.0.1/${PROXY_PORT}" 2>/dev/null; then
        log "${GREEN}✓${NC} 代理端口可连通"
    else
        log "${YELLOW}⚠${NC} 代理端口当前不可连通，请确认 Windows 代理已启动。"
        read -r -p "仍然继续配置？[y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
    fi
}

main() {
    [[ $# -eq 0 ]] || die "此脚本不接受参数，请直接执行：./wsl-proxy-v3.sh"
    [[ "$EUID" -ne 0 ]] || die "请以普通用户执行脚本，脚本会在需要时调用 sudo"
    require_commands
    check_environment

    log "${BLUE}WSL 代理配置脚本 v${SCRIPT_VERSION}${NC}"
    log "代理端口: ${GREEN}${PROXY_PORT}${NC}（mixed）"
    check_proxy_port

    install_bashrc_block

    switch_ubuntu_sources

    log "${YELLOW}[5/5] 更新 APT 软件包列表...${NC}"
    sudo apt update
    log "${GREEN}✓${NC} APT 更新完成；未自动执行 apt upgrade"

    ensure_git
    configure_git_proxy

    log "${YELLOW}[6/6] 配置 WSL Windows 磁盘挂载...${NC}"
    configure_wsl_mount

    log ""
    log "${GREEN}配置完成！${NC}"
    log "请执行以下命令加载配置："
    log "  source ~/.bashrc"
    log "然后按需使用："
    log "  proxy       开启代理"
    log "  noproxy     关闭代理"
    log "  proxystat   查看状态"
}

main "$@"
