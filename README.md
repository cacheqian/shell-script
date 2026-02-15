# Shell Scripts for Ubuntu 24.04 Server

适用于 Ubuntu 24.04 服务器的 Shell 脚本集合。

## 脚本列表

### 1. SSH 安全加固脚本 (`enhance-ssh-secure.sh`)

一键加固 SSH 配置，提升服务器安全性。

**功能：**
- 修改 SSH 端口（自定义或保持默认 22）
- 部署 SSH 公钥认证
- 禁用密码认证
- 适配 Ubuntu 24.04 的 systemd socket 模式
- 自动备份原有配置
- 配置验证与回滚机制

**使用方法：**
```bash
wget -qO- https://raw.githubusercontent.com/cacheqian/shell-script/refs/heads/main/enhance-ssh-secure.sh | bash
```

**注意事项：**
- 需要 root 权限
- 执行前请确保已生成 SSH 密钥对
- 完成后请保持当前终端，新开终端测试连接

---

### 2. Ubuntu 24.04 网络重装脚本 (`ubuntu2404-reinstall`)

通过网络一键重装纯净的 Ubuntu 24.04 系统。

**功能：**
- 使用官方 Ubuntu Cloud Image（来源可信）
- 自动生成随机 root 密码和 SSH 端口
- 自动检测并配置网络（DHCP/Static）
- 支持 NVMe 和传统磁盘
- 适配云服务器环境

**使用方法：**
```bash
wget -qO- https://raw.githubusercontent.com/cacheqian/shell-script/refs/heads/main/ubuntu2404-reinstall | bash
```

**注意事项：**
- 需要 root 权限
- 仅支持 GRUB 引导，不支持 systemd-boot
- **会清空所有数据**，请提前备份
- 执行前确保有 console/VNC 访问权限
- 请务必保存显示的密码和端口

**工作原理：**
```
当前系统 → 下载 Alpine Linux netboot → 重启进入 Alpine (内存运行)
    ↓
下载 Ubuntu 官方 Cloud Image → DD 写入磁盘 → 配置 cloud-init
    ↓
重启 → 进入全新 Ubuntu 24.04 系统
```

---

## 系统要求

| 脚本 | 要求 |
|------|------|
| SSH 加固 | Ubuntu 24.04, root 权限 |
| 网络重装 | Ubuntu 24.04, root 权限, GRUB 引导 |

## 免责声明

这些脚本会修改系统关键配置，使用前请：
1. 充分理解脚本功能
2. 备份重要数据
3. 在测试环境验证后再用于生产环境

## License

MIT
