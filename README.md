方式1：直接下载运行                                                                                                                                                                                                                   
wget https://raw.githubusercontent.com/cacheqian/shell-script/refs/heads/main/wsl-setting.sh


chmod +x wsl-setting.sh


./wsl-setting.sh


方式2：一行命令执行
curl -fsSL https://raw.githubusercontent.com/cacheqian/shell-script/refs/heads/main/wsl-setting.sh
使用方式

  ./wsl-setting.sh              # 交互式输入端口
  
  ./wsl-setting.sh 7890         # 直接指定端口
  
  ./wsl-setting.sh --help       # 显示帮助


宿主机操作，写入以下内容，路径是C:\Users\username
```
[wsl2]
# --- 你的原有网络配置 (保留) ---
networkingMode=Mirrored

# --- 新增：文件系统物理隔离核心 ---
# 禁止 WSL 引擎在启动时挂载 Windows 磁盘 (C盘, D盘等)
mountDrive=false

[experimental]
# --- 你的原有实验配置 (保留，但请看下文警告) ---
hostAddressLoopback=true

# --- 新增：进程与环境隔离 (防渗透关键) ---
[interop]
# 禁止 WSL 里启动 Windows 程序 (如 notepad.exe, powershell.exe)
enabled=false
# 禁止 Windows 的 PATH 环境变量注入到 WSL (防止路径泄露)
appendWindowsPath=false
```




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

