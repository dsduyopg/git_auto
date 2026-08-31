# Git 自动同步工具包（Linux 版 v2.15）

让文件夹自动同步 Gitee / GitHub，或把云端仓库定时拉取到本地。0 基础可用。

> 作者：wowsony · 仓库：https://github.com/dsduyopg/linux_heima
> 本版本由 **Windows v2.15（PowerShell + NSSM）** 完整移植到 Linux，功能与操作保持一致。

## 和 Windows 版的对照

| 能力 | Windows v2.15 | Linux v2.15 |
|---|---|---|
| 后台服务 | NSSM | systemd（`git-autosync@<名称>.service`） |
| 文件监听 | FileSystemWatcher | inotifywait（3 秒防抖合并） |
| 定时拉取 | 常驻服务 `GitMirrorFetcher` | systemd timer（每小时） |
| 邮件发送 | .NET SmtpClient | python3 smtplib |
| 配置位置 | `%USERPROFILE%` / `%ProgramData%` | `/etc/git-autosync` |
| 使用入口 | 双击 `.bat` | `git-autosync` 命令 |

## 安装

### 别人的电脑能用吗？（兼容性）

| 系统 | rpm 包 | tar.gz 包 |
|---|---|---|
| RHEL / CentOS / Fedora / AlmaLinux / Rocky / openEuler | 支持 | 支持 |
| Debian / Ubuntu / 统信 UOS / 麒麟 | 不支持（rpm 是 RHEL 系专有格式） | 支持 |
| Arch / Manjaro | 不支持 | 支持 |
| Alpine / Docker 容器 / 老 SysVinit 系统 | 不支持 | 部分（无 systemd，服务不自动启动） |

给非 RHEL 系的用户，请发 **tar.gz** 包；`install.sh` 会自动识别发行版并给出对应的依赖安装命令（dnf / apt / zypper / pacman / apk）。

无 systemd 的环境（Docker、部分 WSL）同步功能仍可用，只是不会开机自启，需手动运行：

```bash
sudo /opt/git-autosync/bin/git-autosync-sync <仓库名>
# 定时拉取可用常驻模式
nohup sudo /opt/git-autosync/bin/git-autosync-fetch --daemon &
```

### 方式一：rpm 包（推荐）

```bash
sudo dnf install -y git-autosync-2.15-1.*.noarch.rpm
# 卸载：sudo dnf remove git-autosync
```

### 方式二：tar.gz 免安装版

```bash
tar -xzf git-autosync-2.15.tar.gz
cd git-autosync-2.15
sudo bash install.sh       # 卸载：sudo bash uninstall.sh
```

### 依赖

```bash
sudo dnf install -y git inotify-tools python3
```

- `git`、`inotify-tools`：必需
- `python3`：仅邮件通知功能需要（不装也不影响同步）

## 快速开始

```bash
sudo git-autosync env      # 1. 环境自检（Git / inotify / SSH 钥匙）
sudo git-autosync          # 2. 打开交互式主菜单
```

主菜单：

```
  1) 环境自检                    检查 Git / inotify / SSH 钥匙
  2) 生成 SSH 密钥               一键生成并复制公钥
  3) 新建自动推送仓库            本地文件夹 → 云端（实时自动推送）
  4) 移除推送目录                停止推送某个子目录（本地文件保留）
  5) 新建云端镜像拉取            云端 → 本地（立即克隆 + 定时更新）
  6) 定时拉取服务                启用 / 停用 / 设置间隔
  7) 查看仓库与服务状态
  8) 启动 / 停止 / 重启服务
  9) 卸载服务（可同时删除仓库）
 10) 修复服务
 11) 彻底重建服务
 12) 邮件通知配置                同步成功/失败自动发邮件（可选）
  0) 退出
```

## 典型用法

### 本地文件夹自动推送到云端

```bash
sudo git-autosync new
```

按提示依次填写：SSH 私钥 → 提交身份 → 本地文件夹路径 → 要排除的目录 → 平台（Gitee/GitHub）→ 远端 SSH 地址。
完成后会自动 `git init`、写 `.gitignore`、创建 systemd 服务并设为**开机自启**，此后文件夹内任何改动都会在约 3 秒后自动 commit + push。

> GitHub 会自动改用 443 端口（`ssh.github.com:443`），兼容封锁 22 端口的网络。

### 云端仓库定时拉取到本地

```bash
sudo git-autosync mirror          # 登记并立即克隆
sudo git-autosync fetch-timer     # 启用定时拉取（默认每小时，可改间隔）
```

登记表：`/etc/git-autosync/mirror_config.txt`，每行格式：

```
目标目录|远端URL|分支|SSH密钥路径
```

> 定时拉取会执行 `reset --hard` 并清理未跟踪文件，镜像目录里的本地改动会被云端覆盖。
> 设置 `GIT_MIRROR_CLEAN=0` 可关闭清理未跟踪文件。

### 服务管理

```bash
sudo git-autosync list                  # 列出所有仓库及状态
sudo git-autosync status                # 查看服务详情
sudo git-autosync restart <仓库名>       # 重启某个仓库的同步服务
sudo git-autosync uninstall <仓库名>     # 卸载服务（可选同时删除仓库文件）
sudo git-autosync fix                   # 修复所有服务（清理残留锁并重启）
sudo git-autosync rebuild               # 彻底重建所有服务
```

等价的 systemctl 命令：

```bash
sudo systemctl status git-autosync@<仓库名>.service
sudo journalctl -u git-autosync@<仓库名> -f
```

## 邮件通知（可选，默认关闭）

```bash
sudo git-autosync mail
```

选 `[1]` 开启并绑定 SMTP → 选邮箱类型（内置 QQ / 163 / Gmail 预设）→ 填写发件邮箱、**SMTP 授权码**、收件人 → 选 `[3]` 发测试邮件。

> **授权码不是邮箱登录密码**。QQ 邮箱在「设置 - 账户 - POP3/SMTP服务」生成；163 邮箱在「设置 - POP3/SMTP/IMAP」生成。
> 不配置 = 一封都不发，行为与 v2.14 完全一致。

## 目录结构

```
/opt/git-autosync/
├── bin/
│   ├── git-autosync              主命令（交互式菜单 + 子命令）
│   ├── git-autosync-sync         实时同步守护（由 systemd 调用）
│   ├── git-autosync-fetch        云端镜像拉取器
│   ├── git-autosync-mail         邮件发送（python3）
│   ├── git-autosync-mail-config  邮件配置向导
│   └── git-autosync-env          环境自检
├── lib/common.sh                 公共函数库
├── systemd/                      systemd 单元模板
├── docs/                         入门教程
├── VERSION.txt / README.md / LICENSE
└── install.sh / uninstall.sh
```

配置与日志：

| 路径 | 用途 |
|---|---|
| `/etc/git-autosync/repos/<名称>.conf` | 每个仓库的同步配置 |
| `/etc/git-autosync/mirror_config.txt` | 云端镜像拉取登记表 |
| `/etc/git-autosync/mail_config.txt` | SMTP 邮件配置（权限 0600） |
| `/var/log/git-autosync/` | 拉取与邮件日志 |
| 仓库内 `git_sync.log` | 该仓库的同步日志 |

## 无 systemd 环境（WSL / 容器）

若 `git-autosync env` 提示没有 systemd，仍可前台或后台运行同步：

```bash
sudo /opt/git-autosync/bin/git-autosync-sync <仓库名>
# 或常驻后台
nohup sudo /opt/git-autosync/bin/git-autosync-sync <仓库名> &
```

定时拉取可使用常驻模式（等价 Windows 版行为）：

```bash
nohup sudo /opt/git-autosync/bin/git-autosync-fetch --daemon &
```

## 许可

MIT License，详见 `LICENSE`。
