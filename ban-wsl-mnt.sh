#!/usr/bin/env bash
# ============================================================
# WSL C 盘只读挂载配置脚本（方案一）
# 作用：关闭 Windows 盘自动挂载，改用 fstab 将 C: 以只读(ro)挂载到 /mnt/c
# 用法：保存到 Linux 侧（如 ~/setup-ro-c.sh），然后在 WSL 里执行：
#       sudo bash ~/setup-ro-c.sh
# 注意：不要在 /mnt/c 下的目录里运行本脚本
# ============================================================
set -euo pipefail

DRIVE="${1:-C}"                                   # 可选参数：盘符，默认 C
DRIVE_UPPER="$(echo "$DRIVE" | tr 'a-z' 'A-Z')"
MNT="/mnt/$(echo "$DRIVE" | tr 'A-Z' 'a-z')"
WSL_CONF=/etc/wsl.conf
FSTAB=/etc/fstab
TS="$(date +%Y%m%d-%H%M%S)"

# ---------- 0. 前置检查 ----------
if [[ $EUID -ne 0 ]]; then
  echo "[x] 需要 root 权限，请用：sudo bash $0" >&2
  exit 1
fi
if [[ "$PWD" == /mnt/* ]]; then
  echo "[x] 当前目录在 /mnt 下，重新挂载会失败。请 cd ~ 之后再运行。" >&2
  exit 1
fi
echo "[*] 目标：${DRIVE_UPPER}: 只读挂载到 ${MNT}"

# ---------- 1. 备份 ----------
for f in "$WSL_CONF" "$FSTAB"; do
  if [[ -f "$f" ]]; then
    cp -a "$f" "${f}.bak.${TS}"
    echo "[*] 已备份 $f -> ${f}.bak.${TS}"
  fi
done

# ---------- 2. 配置 /etc/wsl.conf（保留你已有的其他配置段） ----------
python3 - "$WSL_CONF" <<'PY'
import os, sys, configparser

path = sys.argv[1]
cp = configparser.ConfigParser()
cp.optionxform = str                              # 保留键名大小写（mountFsTab 等）

try:
    if os.path.exists(path):
        cp.read(path, encoding="utf-8")
except configparser.Error as e:
    sys.exit(f"[x] 解析 {path} 失败（备份已在同目录）：{e}")

if not cp.has_section("automount"):
    cp.add_section("automount")
cp.set("automount", "enabled", "false")           # 关闭 Windows 盘自动挂载
cp.set("automount", "mountFsTab", "true")         # 启动时处理 /etc/fstab

with open(path, "w", encoding="utf-8") as f:
    cp.write(f)
print(f"[*] {path} 已设置 [automount] enabled=false, mountFsTab=true")
PY

# ---------- 3. 配置 /etc/fstab（幂等：先清掉同挂载点的旧条目） ----------
touch "$FSTAB"
sed -i "\#[[:space:]]${MNT}[[:space:]]#d" "$FSTAB"
mkdir -p "$MNT"
echo "${DRIVE_UPPER}: ${MNT} drvfs defaults,ro 0 0" >> "$FSTAB"
echo "[*] fstab 已写入：${DRIVE_UPPER}: ${MNT} drvfs defaults,ro 0 0"

# ---------- 4. 立即生效（被占用则提示重启 WSL） ----------
if mountpoint -q "$MNT"; then
  if umount "$MNT" 2>/dev/null; then
    mount "$MNT"
    echo "[*] 已重新挂载为只读"
  else
    echo "[!] ${MNT} 正被占用，无法立即重新挂载"
    echo "    请在 Windows PowerShell 执行 wsl --shutdown 后重新打开 WSL"
  fi
else
  mount "$MNT" 2>/dev/null || true
fi

# ---------- 5. 验证 ----------
echo
echo "===== 验证 ====="
mount | grep " on ${MNT} " || echo "[!] ${MNT} 当前未挂载"
if touch "${MNT}/.ro-test-$$" 2>/dev/null; then
  rm -f "${MNT}/.ro-test-$$"
  echo "[x] 警告：${MNT} 仍然可写！请 wsl --shutdown 后重新打开 WSL 再验证"
else
  echo "[√] 写入测试被拒绝，${DRIVE_UPPER}: 盘已只读"
fi

# ---------- 6. 完成提示 ----------
cat <<EOF

完成。说明：
1. 以后每次启动 WSL 都会自动按 fstab 只读挂载 ${DRIVE_UPPER}:，无需再跑本脚本
2. VS Code Remote-WSL 和 code . 不受影响（只需要读取权限）
3. Windows 侧 \\\\wsl\$ 访问 Linux 文件不受影响
4. 回滚方法（然后 wsl --shutdown）：
   cp ${WSL_CONF}.bak.${TS} ${WSL_CONF}
   cp ${FSTAB}.bak.${TS} ${FSTAB}
EOF
