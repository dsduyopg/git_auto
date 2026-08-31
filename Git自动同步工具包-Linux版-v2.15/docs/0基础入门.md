# 0 基础入门（Linux 版）

这篇教程面向完全没接触过命令行的同学，跟着做就能让文件夹自动同步到 Gitee / GitHub。

## 第 0 步：安装

如果拿到的是 rpm 包：

```bash
sudo dnf install -y git-autosync-2.15-1.*.noarch.rpm
```

如果是 tar.gz 包：

```bash
tar -xzf git-autosync-2.15.tar.gz
cd git-autosync-2.15
sudo bash install.sh
```

装完先自检：

```bash
sudo git-autosync env
```

看到"环境检查通过"就可以继续；如果有红色报错，按提示安装缺少的依赖：

```bash
sudo dnf install -y git inotify-tools python3
```

## 第 1 步：生成 SSH 钥匙（只需做一次）

```bash
sudo git-autosync ssh-key
```

按提示输入邮箱，回车即可。屏幕会打印一段以 `ssh-ed25519` 开头的内容，全部复制。

粘贴到云端：

- **Gitee**：右上角头像 → 设置 → SSH 公钥 → 粘贴 → 确定
- **GitHub**：右上角头像 → Settings → SSH and GPG keys → New SSH key → 粘贴 → Add SSH key

## 第 2 步：让文件夹自动推送到云端

```bash
sudo git-autosync new
```

依次回答：

1. **SSH 私钥**：列出来了就选 `1`，直接回车即可
2. **user.name / user.email**：随便填，会记录在提交记录里
3. **本地文件夹路径**：要同步的文件夹，例如 `/home/你的用户名/文档`
4. **要排除的目录**：不想同步的子目录，逗号分隔，例如 `node_modules,temp`（可以留空）
5. **平台**：Gitee 选 1，GitHub 选 2（分支名会自动给 master / main，可改）
6. **远端 SSH 地址**：在 Gitee/GitHub 仓库页面点"克隆"，选 SSH 方式复制，形如
   `git@github.com:你的用户名/仓库名.git`

出现"完成！"即成功。此后：

- 文件夹里**新建、修改、删除**文件，约 3 秒后自动提交并推送
- 提交信息形如 `auto-sync: 2026-08-31 22:10:00`
- **开机自动启动**，不用管它

想看它在干什么：

```bash
sudo git-autosync status                      # 服务状态
tail -f /你的文件夹/git_sync.log               # 同步日志
```

## 第 3 步（可选）：把云端仓库定时拉到本地

适合"在公司推、回家拉"的场景。

```bash
sudo git-autosync mirror
```

填写云端 SSH 地址、本地目录、分支名，会立即克隆一次。然后开启定时：

```bash
sudo git-autosync fetch-timer      # 选 1 启用，默认每小时拉一次
```

> 注意：定时拉取会用云端内容**覆盖**本地镜像目录的改动，镜像目录里不要放本地独有的文件。
> 想保留未跟踪文件，可在调用前设置 `GIT_MIRROR_CLEAN=0`。

## 第 4 步（可选）：同步结果发邮件通知

```bash
sudo git-autosync mail
```

1. 选 `[1]` 开启并绑定 SMTP
2. 选邮箱类型（QQ / 163 / Gmail / 自定义）
3. 填写发件邮箱、**SMTP 授权码**、收件人
4. 选 `[3]` 发测试邮件，收到就说明成功了

**授权码不是邮箱密码**：

- QQ 邮箱：设置 → 账户 → POP3/SMTP服务 → 生成授权码
- 163 邮箱：设置 → POP3/SMTP/IMAP → 开启 → 生成授权码

不想要了：选 `[2]` 关闭，一封都不会发。

## 常见问题

**Q：改动后没推送？**

```bash
sudo git-autosync status            # 看服务是不是 running
sudo git-autosync fix               # 修复并重启
```

**Q：卡住不动了？**

多半是残留的 `index.lock`。执行 `sudo git-autosync fix` 会自动清理。

**Q：某些目录不想推送？**

```bash
sudo git-autosync remove            # 选仓库，填相对路径，本地文件会保留
```

**Q：想换电脑 / 不想用了？**

```bash
sudo git-autosync uninstall         # 选仓库卸载服务（默认保留文件）
sudo dnf remove git-autosync        # rpm 安装的卸载整个工具包
```

**Q：WSL / 容器里没有 systemd？**

`git-autosync new` 仍会生成配置，只是不会自动启动服务。手动运行即可：

```bash
sudo /opt/git-autosync/bin/git-autosync-sync <仓库名>
```
