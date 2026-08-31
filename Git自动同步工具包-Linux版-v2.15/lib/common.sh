#!/usr/bin/env bash
# ============================================================
# Git 自动同步工具包 (Linux 版) - 公共函数库
# 由 Windows v2.15 (PowerShell/NSSM) 移植
# 提供：路径约定、颜色输出、日志、配置读写、依赖检查
# ============================================================

# 中文/UTF-8 输出环境
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

# ---- 路径约定（可用环境变量覆盖，便于本地调试） ----
PREFIX="${GIT_AUTOSYNC_PREFIX:-/opt/git-autosync}"
CONF_DIR="${GIT_AUTOSYNC_CONF:-/etc/git-autosync}"
REPO_CONF_DIR="${CONF_DIR}/repos"
MAIL_CONF="${CONF_DIR}/mail_config.txt"
MIRROR_CONF="${CONF_DIR}/mirror_config.txt"
MIRROR_SETTINGS="${CONF_DIR}/mirror_settings.txt"
MAIL_LOG="${CONF_DIR}/git_mail_notify.log"
LAST_NOTIFY="${CONF_DIR}/last_notify.tmp"
UNIT_DIR="${GIT_AUTOSYNC_UNIT_DIR:-/etc/systemd/system}"

SYNC_SERVICE="git-autosync@.service"
FETCH_SERVICE="git-autosync-fetch.service"
FETCH_TIMER="git-autosync-fetch.timer"

VERSION="2.15"

# ---- 颜色（非终端自动关闭） ----
if [ -t 1 ]; then
    C_RED='\033[31m'; C_GREEN='\033[32m'; C_YELLOW='\033[33m'
    C_BLUE='\033[36m'; C_GRAY='\033[90m'; C_BOLD='\033[1m'; C_OFF='\033[0m'
else
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_GRAY=''; C_BOLD=''; C_OFF=''
fi

info()  { echo -e "${C_BLUE}[信息]${C_OFF} $*"; }
ok()    { echo -e "${C_GREEN}[成功]${C_OFF} $*"; }
warn()  { echo -e "${C_YELLOW}[警告]${C_OFF} $*"; }
err()   { echo -e "${C_RED}[错误]${C_OFF} $*" >&2; }
title() { echo -e "\n${C_BOLD}$*${C_OFF}"; }
hr()    { echo -e "${C_GRAY}----------------------------------------------------------${C_OFF}"; }

# ---- 日志：同时输出到屏幕和文件 ----
log_line() {
    local logfile="$1"; shift
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" 2>/dev/null | tee -a "$logfile" 2>/dev/null
}

# ---- 读取 key=value 配置（取最后一个匹配项） ----
conf_get() {
    local file="$1" key="$2" val
    [ -f "$file" ] || return 1
    val=$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$file" 2>/dev/null | tail -n1)
    [ -n "$val" ] || return 1
    printf '%s' "$val"
}

# ---- 写入/更新 key=value 配置（不存在则追加） ----
conf_set() {
    local file="$1" key="$2" val="$3"
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null; then
        sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key}=${val}|" "$file"
    else
        printf '%s=%s\n' "$key" "$val" >> "$file"
    fi
}

# ---- 依赖检查 ----
need_cmd() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
    local c
    for c in "$@"; do
        if ! need_cmd "$c"; then
            err "缺少依赖命令：$c"
            return 1
        fi
    done
    return 0
}

has_systemd() { [ -d /run/systemd/system ] && need_cmd systemctl; }

# ---- 仓库配置：列出所有已登记仓库名 ----
list_repos() {
    [ -d "$REPO_CONF_DIR" ] || return 0
    find "$REPO_CONF_DIR" -maxdepth 1 -name '*.conf' -printf '%f\n' 2>/dev/null \
        | sed 's/\.conf$//' | sort
}

# ---- 构造 SSH 命令（指定私钥） ----
ssh_cmd_for() {
    local key="$1"
    if [ -n "$key" ] && [ -f "$key" ]; then
        printf 'ssh -i %s -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new' "$key"
    else
        printf 'ssh -o StrictHostKeyChecking=accept-new'
    fi
}

# ---- 清理残留 index.lock（Windows 版 v2.14 起的核心防卡死逻辑） ----
clear_index_lock() {
    local repo="$1" lock="${1}/.git/index.lock"
    if [ -f "$lock" ]; then
        # 仅清理超过 60 秒未被修改的僵尸锁，避免误删正在进行的 git 操作
        local age=$(( $(date +%s) - $(stat -c %Y "$lock" 2>/dev/null || echo 0) ))
        if [ "$age" -gt 60 ]; then
            rm -f "$lock" && warn "已清理残留锁：${lock}（${age} 秒未变动）"
            return 0
        fi
    fi
    return 0
}

# ---- 规范化服务名：仅保留合法 systemd 实例字符 ----
safe_name() {
    printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_' | sed 's/_*$//'
}

# ---- 确认提示 ----
confirm() {
    local prompt="${1:-确定继续?}" ans
    read -r -p "$(echo -e "${C_YELLOW}${prompt}${C_OFF} [y/N]: ")" ans
    case "$ans" in [yY]*) return 0;; *) return 1;; esac
}

# ---- 读取输入（带默认值） ----
ask() {
    local prompt="$1" default="${2:-}" var
    if [ -n "$default" ]; then
        read -r -p "$prompt [$default]: " var
        printf '%s' "${var:-$default}"
    else
        read -r -p "$prompt: " var
        printf '%s' "$var"
    fi
}
