enhance-ssh-secure.sh

wget -O secure_ssh.sh https://raw.githubusercontent.com/cacheqian/shell-script/main/enhance-ssh-secure.sh && chmod +x secure_ssh.sh && sudo ./secure_ssh.sh

这个脚本专门针对 Ubuntu 24.04 LTS 进行了深度适配，主要解决了新版系统 SSH 架构变化带来的配置不生效问题。核心逻辑包含四个层面：

A. 配置优先级的抢占 (Anti-Override)
问题：Ubuntu 默认会通过 Include 指令引入 /etc/ssh/sshd_config.d/ 下的子配置文件（通常由 Cloud-init 生成）。这些子配置的优先级极高，往往会覆盖我们手动修改的端口号，导致怎么改端口都不生效。

脚本原理：脚本会自动注释掉主配置文件中的 Include 行。这相当于切断了云厂商默认配置的干扰，强制 SSH 服务只读取并执行主配置文件中的设定，确保我们设置的端口 100% 生效。

B. 运行模式的切换 (Socket vs Service)
问题：Ubuntu 24.04 引入了 ssh.socket 机制。默认情况下，系统并不运行 SSH 服务进程，而是由 systemd 监听 22 端口，有流量来时才唤醒 SSH。这种机制非常顽固，常常导致自定义端口无法被监听。

脚本原理：脚本会自动停止并禁用 ssh.socket，转而启用传统的 ssh.service（守护进程模式）。这让 SSH 服务回归到经典的“常驻后台监听”模式，从而稳定支持任意自定义端口。

C. 特权分离目录的自动修复 (Runtime Fix)
问题：在某些修改端口或重启的场景下，OpenSSH 运行所必需的临时目录 /run/sshd 可能未被创建，导致服务启动失败并报错 Missing privilege separation directory。

脚本原理：脚本在重启服务前会主动检查该目录，如果缺失则自动创建并赋予正确的权限，消除启动报错隐患。

D. 原子化配置写入 (Safety)
原理：

追加而非覆盖：对于 Port，脚本采用“注释旧行 + 追加新行”的策略，而不是直接替换。这保证了即使多次运行脚本，配置文件也不会乱。

自动备份与回滚：脚本执行修改前会创建带时间戳的备份。如果 sshd -t 语法检查失败，脚本会自动将配置文件恢复原状，防止服务器失联。
