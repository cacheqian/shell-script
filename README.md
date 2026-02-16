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


原始宿主机.wslconfig备份
```
[wsl2]
networkingMode=Mirrored
[experimental]
hostAddressLoopback=true
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

