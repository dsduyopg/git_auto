# git-autosync (Linux)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/dsduyopg/git_auto/blob/main/LICENSE)

A Git automatic synchronization toolkit for Linux. Auto-push local folders to Gitee / GitHub, or periodically pull remote repositories to local directories. Designed for zero-experience users.

> 中文版简介：这是一款面向 Linux 的 Git 自动同步工具包。本地文件夹改动后约 3 秒自动 commit + push 到 Gitee / GitHub；也可以把云端仓库定时拉取到本地。0 基础可用。

This is the Linux port of the Windows v2.15 version (PowerShell + NSSM), using filesystem event monitoring / systemd / systemd-timer / python3.

## Features

- Real-time two-way sync (watch → commit → push / pull)
- systemd timer for periodic pull
- One-shot service install / repair / rebuild / uninstall
- Optional email notification on success / failure (off by default)
- Auto-cleanup of stale `index.lock` to avoid sync stalls
- CLI output defaults to **English**, with an optional **Chinese** mode
- Runs on RHEL / CentOS / Fedora / AlmaLinux / Rocky / EPEL

## Installation

### RPM package (recommended)

```bash
sudo dnf install ./git-autosync-2.15-6.el10.noarch.rpm
# Uninstall: sudo dnf remove git-autosync
```

### Tarball (no install)

```bash
tar -xzf git-autosync-2.15.tar.gz
cd git-autosync-2.15
sudo bash install.sh
# Uninstall: sudo bash uninstall.sh
```

### Dependencies

```bash
sudo dnf install -y git inotify-tools python3
```

- `git`, `inotify-tools`: required
- `python3`: only needed for email notifications

## Quick Start

```bash
sudo git-autosync env      # Environment check
sudo git-autosync          # Interactive main menu
```

## Language Switch

The main menu defaults to English. You can switch to Chinese from the menu:

```
[Settings] → Language / 语言 → 中文
```

All user-facing output, prompts, logs, and email templates will follow the selected language.

## Common Commands

```bash
sudo git-autosync new          # Create a new auto-push repository
sudo git-autosync mirror       # Register and clone a remote mirror
sudo git-autosync fetch-timer  # Enable periodic pull timer
sudo git-autosync list         # List all repositories and status
sudo git-autosync status       # Show service details
sudo git-autosync restart <name>
sudo git-autosync uninstall <name>
sudo git-autosync fix          # Fix all services
sudo git-autosync rebuild      # Rebuild all services
```

Equivalent systemd commands:

```bash
sudo systemctl status git-autosync@<name>.service
sudo journalctl -u git-autosync@<name> -f
```

## Paths

| Path | Purpose |
|---|---|
| `/usr/share/git-autosync` | Program files |
| `/usr/bin/git-autosync` | Command entry point |
| `/etc/git-autosync/repos/<name>.conf` | Per-repository sync config |
| `/etc/git-autosync/mirror_config.txt` | Mirror / periodic pull registry |
| `/etc/git-autosync/mail_config.txt` | SMTP config (mode 0600) |
| `/var/log/git-autosync/` | Pull and mail logs |
| `<repo>/git_sync.log` | Per-repository sync log |

## License

MIT License. See [LICENSE](LICENSE).
