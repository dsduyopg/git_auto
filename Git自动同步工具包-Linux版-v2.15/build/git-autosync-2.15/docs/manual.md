# Git 自动同步工具包（Linux 版 v2.15）使用手册

> 作者：wowsony　仓库：https://github.com/dsduyopg/linux_heima
> 本版本由 Windows v2.15（PowerShell + NSSM）移植，功能与操作保持一致。

---

## 目录

1. [产品简介](#1-产品简介)
2. [系统要求](#2-系统要求)
3. [安装](#3-安装)
4. [快速上手（3 步）](#4-快速上手3-步)
5. [功能详解](#5-功能详解)
6. [命令参考](#6-命令参考)
7. [服务管理（systemctl）](#7-服务管理systemctl)
8. [配置文件说明](#8-配置文件说明)
9. [日志与故障排查](#9-日志与故障排查)
10. [常见问题 FAQ](#10-常见问题-faq)
11. [卸载](#11-卸载)
12. [附录](#12-附录)

---

## 1. 产品简介

让文件夹自动同步 Gitee / GitHub，或把云端仓库定时拉取到本地，0 基础可用。

**两种典型用法：**

- **本地 → 云端**：指定一个文件夹，里面任何改动（新建/修改/删除）约 3 秒后自动提交并推送到 Gitee/GitHub
- **云端 → 本地**：登记一个云端仓库，定时（默认每小时）自动拉取到本地目录

**技术移植对照：**

| 能力 | Windows v2.15 | Linux v2.15 |
|---|---|---|
| 后台服务 | NSSM | systemd |
| 文件监听 | FileSystemWatcher | inotifywait（3 秒防抖） |
| 定时拉取 | 常驻服务 | systemd timer |
| 邮件发送 | .NET SmtpClient | python3 smtplib |
| 配置位置 | `%USERPROFILE%` / `%ProgramData%` | `/etc/git-autosync` |
| 使用入口 | 双击 `.bat` | `git-autosync` 命令 |

---

## 2. 系统要求

| 项目 | 要求 |
|---|---|
| 操作系统 | 使用 systemd 的 Linux（RHEL/CentOS/Fedora/Alma/Rocky/Ubuntu/Debian/Arch…） |
| 必需依赖 | `bash`(4.0+)、`git`、`inotify-tools` |
| 可选依赖 | `python3`（仅邮件通知需要） |
| 权限 | 安装与建仓库需要 root（sudo） |
| 架构 | 纯脚本，`noarch`，x86_64 / aarch64 通用 |

> **注意**：RHEL / CentOS / Rocky / Alma 上 `inotify-tools` 通常在 **EPEL** 源，需先执行
> `sudo dnf install -y epel-release`。

---

## 3. 安装

### 3.1 rpm 包（RHEL 系推荐）

```bash
sudo dnf install -y git-autosync-2.15-1.el10.noarch.rpm
```

### 3.2 tar.gz 免安装版（所有 Linux 通用）

```bash
tar -xzf git-autosync-2.15.tar.gz
cd git-autosync-2.15
sudo bash install.sh
```

`install.sh` 会自动识别发行版，缺依赖时给出对应的安装命令（dnf / apt / zypper / pacman / apk）。

### 3.3 安装内容

| 路径 | 说明 |
|---|---|
| `/opt/git-autosync/` | 程序主体（bin、lib、systemd、docs） |
| `/usr/bin/git-autosync` | 命令入口（软链接） |
| `/usr/lib/systemd/system/git-autosync@.service` | 推送服务模板 |
| `/usr/lib/systemd/system/git-autosync-fetch.{service,timer}` | 定时拉取 |
| `/etc/git-autosync/` | 配置目录 |
| `/var/log/git-autosync/` | 日志目录 |
| `/usr/share/man/man1/git-autosync.1.gz` | man 手册页 |

### 3.4 验证安装

```bash
git-autosync env          # 环境自检
man git-autosync          # 查看手册
git-autosync help         # 查看命令用法
```

---

## 4. 快速上手（3 步）

### 第 1 步：环境自检

```bash
sudo git-autosync env
```

看到「环境检查通过」即继续；有红色报错按提示安装缺失依赖。

### 第 2 步：生成 SSH 钥匙（只需做一次）

```bash
sudo git-autosync ssh-key
```

输入邮箱后，屏幕打印一段 `ssh-ed25519` 开头的内容，**全部复制**并添加到云端：

- **Gitee**：设置 → SSH 公钥 → 粘贴
- **GitHub**：Settings → SSH and GPG keys → New SSH key → 粘贴

### 第 3 步：让文件夹自动推送

```bash
sudo git-autosync new
```

按提示填写：

| 提示 | 说明 |
|---|---|
| SSH 私钥 | 直接回车使用列出的第 1 个 |
| user.name / user.email | 提交记录的作者信息 |
| 本地文件夹路径 | 要同步的文件夹 |
| 要排除的目录 | 逗号分隔，可留空 |
| 平台 | Gitee 选 `1`（master），GitHub 选 `2`（main） |
| 远端 SSH 地址 | 如 `git@github.com:用户名/仓库.git` |

出现「完成！」即成功。此后文件改动约 3 秒后自动同步，且**开机自启**。

---

## 5. 功能详解

### 5.1 环境自检

```bash
sudo git-autosync env
```

检查 Git、inotify-tools、SSH 私钥、systemd、python3 是否就绪，并列出已登记仓库。

### 5.2 生成 SSH 密钥

```bash
sudo git-autosync ssh-key
```

生成 ed25519 密钥，自动处理属主权限，并打印公钥供复制。

### 5.3 新建自动推送仓库

```bash
sudo git-autosync new
```

**它会依次执行：**

1. 选择 SSH 私钥
2. 设置提交身份（user.name / user.email）
3. 创建/指定本地文件夹
4. 设置排除项（写入 `.gitignore` 并 `git rm --cached`，本地文件保留）
5. 选择平台与分支
6. 填写远端地址（GitHub 自动改用 443 端口以绕开 22 端口封锁）
7. `git init` + 配置 `core.sshCommand` + 首次 `pull`
8. 生成配置 `/etc/git-autosync/repos/<仓库名>.conf`
9. 创建并启动 systemd 服务 `git-autosync@<仓库名>.service`，设为开机自启

### 5.4 移除推送目录

```bash
sudo git-autosync remove
```

把某个子目录从 Git 跟踪中移除并写入 `.gitignore`，**本地文件保留**。

### 5.5 新建云端镜像拉取

```bash
sudo git-autosync mirror
```

登记远端地址与本地目录（写入 `/etc/git-autosync/mirror_config.txt`），并可选择立即克隆。

> 拉取会执行 `reset --hard` + `clean -fd`，镜像目录里的本地改动会被云端覆盖。
> 设置 `GIT_MIRROR_CLEAN=0` 可关闭清理未跟踪文件。

### 5.6 定时拉取服务

```bash
sudo git-autosync fetch-timer
```

子菜单：

1. 启用定时拉取（开机自启 + 定时触发）
2. 停用定时拉取
3. 设置拉取间隔（分钟，1–1440，默认 60）
4. 立即执行一次拉取

### 5.7 服务管理

```bash
sudo git-autosync list       # 列出所有仓库及状态
sudo git-autosync status     # 查看服务详情
sudo git-autosync restart <仓库名>
sudo git-autosync uninstall <仓库名>
```

`uninstall` 会停止并禁用服务、删除配置，**默认保留仓库文件**（可选择一并删除）。

### 5.8 修复与重建

```bash
sudo git-autosync fix        # 清理残留 index.lock 并重启所有服务
sudo git-autosync rebuild    # 彻底重建所有服务（停止→重装单元→重新启用）
```

### 5.9 邮件通知（可选，默认关闭）

```bash
sudo git-autosync mail
```

| 选项 | 功能 |
|---|---|
| 1 | 开启并绑定 SMTP（内置 QQ / 163 / Gmail 预设） |
| 2 | 关闭邮件通知 |
| 3 | 发送测试邮件（跳过节流） |
| 4 | 管理收件人 |
| 5 | 设置通知间隔（聚合窗口，防刷屏） |
| 6 | 为指定仓库开关邮件通知 |
| 7 | 查看邮件日志 |

**关键点：**

- 填写的是 **SMTP 授权码**，不是邮箱登录密码
- 输入时屏幕不显示任何字符（防偷窥），需连输两遍确认
- 必须再用选项 6 给**具体仓库**开启邮件通知，才会真的发信
- 不配置 = 一封都不发，行为与 v2.14 完全一致

---

## 6. 命令参考

```
用法: git-autosync [命令] [参数]

不带参数运行 = 打开交互式主菜单

  env                       环境自检
  ssh-key                   生成 SSH 密钥
  new                       新建自动推送仓库（本地 → 云端）
  remove                    移除推送目录
  mirror                    新建云端镜像拉取（云端 → 本地）
  fetch-timer               定时拉取服务管理
  list                      列出已登记仓库
  status                    查看服务状态
  start  <仓库名>           启动服务
  stop   <仓库名>           停止服务
  restart <仓库名>          重启服务
  enable <仓库名>           设为开机自启
  disable <仓库名>          取消开机自启
  uninstall <仓库名>        卸载服务（可选删除仓库）
  fix                       修复所有服务
  rebuild                   彻底重建所有服务
  mail                      邮件通知配置
  help                      显示本帮助
```

---

## 7. 服务管理（systemctl）

服务命名规则：`git-autosync@<仓库名>.service`

```bash
# 单个仓库服务
sudo systemctl status   git-autosync@<仓库名>.service
sudo systemctl start    git-autosync@<仓库名>.service
sudo systemctl stop     git-autosync@<仓库名>.service
sudo systemctl restart  git-autosync@<仓库名>.service
sudo systemctl enable   git-autosync@<仓库名>.service
sudo systemctl disable  git-autosync@<仓库名>.service
sudo systemctl is-enabled git-autosync@<仓库名>.service

# 查看所有同步服务
sudo systemctl list-units 'git-autosync@*' --all

# 实时日志
sudo journalctl -u git-autosync@<仓库名>.service -f

# 定时拉取
sudo systemctl enable --now git-autosync-fetch.timer
sudo systemctl list-timers | grep git-autosync
```

服务单元自带 `Restart=always` + `RestartSec=5`，崩溃后 5 秒自动拉起。

---

## 8. 配置文件说明

### 8.1 仓库配置 `/etc/git-autosync/repos/<仓库名>.conf`

```ini
repo_path=/path/to/repo      # 同步的文件夹
branch=master                # 分支
remote=origin                # 远程名
ssh_key=/root/.ssh/id_ed25519  # SSH 私钥，留空用默认
debounce=3                   # 防抖秒数（连续改动合并）
retry=3                      # 推送失败重试次数
retry_wait=5                 # 重试间隔秒数
mail_notify=0                # 该仓库是否发邮件：1 开 / 0 关
log_file=/path/to/repo/git_sync.log   # 同步日志
exclude=                     # 额外排除（inotify 正则，可选）
```

### 8.2 镜像登记表 `/etc/git-autosync/mirror_config.txt`

```
目标目录|远端URL|分支|SSH密钥路径
```

第 4 列可省略（用默认密钥），`#` 开头为注释。

### 8.3 拉取设置 `/etc/git-autosync/mirror_settings.txt`

```ini
interval=60                  # 拉取间隔（分钟，1-1440）
default_ssh_key=             # 默认私钥路径，留空自动扫描
```

### 8.4 邮件配置 `/etc/git-autosync/mail_config.txt`（权限 0600）

```ini
enabled=1                    # 总开关
smtp_server=smtp.qq.com
smtp_port=465
use_ssl=1
from=you@qq.com
password=SMTP授权码
to=a@b.com,c@d.com
notify_interval=0            # 聚合窗口（分钟），0=即时
```

### 8.5 环境变量

| 变量 | 作用 |
|---|---|
| `GIT_MIRROR_CLEAN=0` | 拉取时不清理未跟踪文件 |
| `GIT_AUTOSYNC_PREFIX` | 覆盖安装目录（调试用） |
| `GIT_AUTOSYNC_CONF` | 覆盖配置目录（调试用） |

---

## 9. 日志与故障排查

| 日志 | 路径 |
|---|---|
| 仓库同步日志 | 仓库内 `git_sync.log` |
| 拉取日志 | `/var/log/git-autosync/mirror_fetcher.log` |
| 邮件日志 | `/var/log/git-autosync/git_mail_notify.log` |
| systemd 日志 | `journalctl -u git-autosync@<仓库名>.service` |

**排查顺序：**

1. 服务在跑吗：`systemctl status git-autosync@<仓库名>.service`
2. 同步日志说什么：`tail -f /你的文件夹/git_sync.log`
3. 卡住了：`sudo git-autosync fix`（清理残留 `index.lock`）
4. 还不行：`sudo git-autosync rebuild`

---

## 10. 常见问题 FAQ

**Q：改动后没推送？**
先看服务状态，再看同步日志。`sudo git-autosync fix` 可解决大部分问题。

**Q：卡住不动？**
多半是残留 `index.lock`，`sudo git-autosync fix` 会自动清理。

**Q：某些目录不想推送？**
`sudo git-autosync remove`，填相对路径，本地文件保留。

**Q：邮件收不到？**
1. 确认全局 SMTP 已开启（`mail` → 选 1）
2. 确认**该仓库**也开了（选 6）
3. 用 `mail` → 选 3 发测试邮件，选 7 看日志

**Q：授权码总说不对？**
必须是邮箱设置里生成的「SMTP 授权码」，不是登录密码；且不要带空格。

**Q：WSL / Docker 里没 systemd？**
同步功能仍可用，只是不自动启动：
```bash
sudo /opt/git-autosync/bin/git-autosync-sync <仓库名>
nohup sudo /opt/git-autosync/bin/git-autosync-fetch --daemon &
```

**Q：WSL 里开机自启吗？**
打开 WSL 时 systemd 会自动拉起所有 `enable` 的服务。若希望 Windows 一开机就跑，需用「任务计划程序」或 NSSM 在 Windows 侧启动 `wsl.exe`。

---

## 11. 卸载

```bash
# 卸载单个仓库的同步服务
sudo git-autosync uninstall

# 卸载整个工具包
sudo dnf remove git-autosync              # rpm 安装
sudo bash /opt/git-autosync/uninstall.sh  # tar.gz 安装
```

卸载时可选择保留或删除配置目录（含 SMTP 授权码）。

---

## 12. 附录

### 附录 A：兼容性矩阵

| 系统 | rpm 包 | tar.gz 包 |
|---|---|---|
| RHEL / CentOS / Fedora / Alma / Rocky / openEuler | 支持 | 支持 |
| Debian / Ubuntu / 统信 UOS / 麒麟 | 不支持 | 支持 |
| Arch / Manjaro | 不支持 | 支持 |
| Alpine / Docker / 老 SysVinit | 不支持 | 部分（无 systemd） |

### 附录 B：目录结构

```
/opt/git-autosync/
├── bin/
│   ├── git-autosync              主命令（菜单 + 子命令）
│   ├── git-autosync-sync         实时同步守护
│   ├── git-autosync-fetch        云端镜像拉取器
│   ├── git-autosync-mail         邮件发送
│   ├── git-autosync-mail-config  邮件配置向导
│   └── git-autosync-env          环境自检
├── lib/common.sh                 公共函数库
├── systemd/                      systemd 单元模板
├── docs/                         manual.md, getting-started.md
├── install.sh / uninstall.sh
└── README.md / VERSION.txt / LICENSE
```

### 附录 C：许可

MIT License，详见 `LICENSE`。
