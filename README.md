# WSL2 配置脚本

这个仓库包含两个面向 WSL2 的配置脚本：

| 脚本 | 作用 | 适用场景 |
| --- | --- | --- |
| `setup-wsl2-ubuntu24.sh` | 配置代理、Git、APT 阿里云源，并将 Windows C 盘设为只读挂载 | 新建的 Ubuntu 24.04 WSL2 开发环境 |
| `ban-wsl-mnt.sh` | 单独关闭 Windows 磁盘自动挂载，并把指定盘符以只读方式挂载 | 只需要限制 WSL 写入 Windows 磁盘 |

> 这些脚本会修改系统配置。运行前请先阅读下方的“重要影响”。

## setup-wsl2-ubuntu24.sh

### 作用

该脚本用于初始化固定环境：

- 仅支持 **WSL2 + Ubuntu 24.04**
- 要求以 `root` 身份执行
- 要求 WSL2 使用 mirrored networking
- 使用 Windows 宿主机上的 mixed 代理：`127.0.0.1:7890`
- 在 `/root/.bashrc` 中添加以下命令：
  - `proxy`：开启当前 Shell 的代理
  - `noproxy`：关闭当前 Shell 的代理
  - `proxystat`：查看当前代理状态
- 为 root 用户配置 Git HTTP/HTTPS 代理
- 将 Ubuntu 官方 APT 源替换为阿里云镜像
- 执行 `apt update`，但不会自动执行 `apt upgrade`
- 关闭 Windows 磁盘自动挂载
- 将 Windows C 盘以只读方式挂载到 `/mnt/c`

### 使用前提

1. Windows 中已经启动代理软件。
2. mixed 代理监听 `127.0.0.1:7890`。
3. WSL2 发行版为 Ubuntu 24.04。
4. WSL2 已启用 mirrored networking。

### 下载并执行

```bash
wget https://raw.githubusercontent.com/cacheqian/shell-script/refs/heads/main/setup-wsl2-ubuntu24.sh
chmod +x setup-wsl2-ubuntu24.sh
sudo ./setup-wsl2-ubuntu24.sh
```

脚本执行完后，在 Windows PowerShell 中运行：

```powershell
wsl --shutdown
```

重新进入 WSL，然后切换到 root Shell 并加载配置：

```bash
sudo -i
source /root/.bashrc
```

按需控制代理：

```bash
proxy
proxystat
noproxy
```

### 重要影响

- Shell 和 Git 代理只为 **root 用户**配置。
- 代理地址和端口固定为 `127.0.0.1:7890`。
- 脚本会关闭所有 Windows 磁盘的自动挂载，只为 C 盘添加只读挂载配置。
- `/etc/wsl.conf`、`/etc/fstab` 和 Ubuntu 软件源会在修改前生成带时间戳的备份。

## ban-wsl-mnt.sh

### 作用

该脚本只处理 Windows 磁盘挂载，不配置代理或软件源：

- 关闭 WSL 的 Windows 磁盘自动挂载
- 启用启动时读取 `/etc/fstab`
- 默认将 Windows C 盘以只读方式挂载到 `/mnt/c`
- 可通过参数指定其他单个盘符
- 修改前备份 `/etc/wsl.conf` 和 `/etc/fstab`
- 尝试立即重新挂载，并验证挂载点是否只读

### 下载并执行

不要在 `/mnt/*` 目录中运行该脚本。先回到 Linux 用户目录：

```bash
cd ~
wget https://raw.githubusercontent.com/cacheqian/shell-script/refs/heads/main/ban-wsl-mnt.sh
chmod +x ban-wsl-mnt.sh
sudo ./ban-wsl-mnt.sh
```

默认处理 C 盘。若要处理其他盘符，例如 D 盘：

```bash
sudo ./ban-wsl-mnt.sh D
```

如果挂载点正在使用，脚本无法立即重新挂载。请在 Windows PowerShell 中执行：

```powershell
wsl --shutdown
```

然后重新进入 WSL，使用以下命令检查挂载状态：

```bash
mount | grep ' on /mnt/c '
touch /mnt/c/.write-test
```

只读挂载正常时，`touch` 应提示只读文件系统或拒绝写入。

### 重要影响

- 脚本会关闭所有 Windows 磁盘的自动挂载。
- 只有传入的盘符会被写入 `/etc/fstab`；其他 Windows 盘不会自动出现。
- 原配置会保存为 `/etc/wsl.conf.bak.<时间戳>` 和 `/etc/fstab.bak.<时间戳>`。
- 如需回滚，请恢复对应备份，然后执行 `wsl --shutdown`。

## 说明

这些脚本会修改 WSL 的系统级配置，建议先在可恢复的 WSL 实例中验证。脚本仅适用于你理解并接受上述影响的环境。
