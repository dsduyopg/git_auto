#!/usr/bin/env bash
# ============================================================
# Git 自动同步工具包 (Linux 版) - 安装脚本
# 供 tar.gz 免安装版使用；rpm 版由包管理器负责安装
#
# 用法: sudo bash install.sh
# 可用环境变量覆盖路径：PREFIX / CONF_DIR / UNIT_DIR / BIN_LINK / LOG_DIR
# ============================================================

set -euo pipefail

PREFIX="${PREFIX:-/opt/git-autosync}"
CONF_DIR="${CONF_DIR:-/etc/git-autosync}"
UNIT_DIR="${UNIT_DIR:-/etc/systemd/system}"
BIN_LINK="${BIN_LINK:-/usr/bin/git-autosync}"
LOG_DIR="${LOG_DIR:-/var/log/git-autosync}"

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "[错误] 请用 root 运行：sudo bash install.sh"
    exit 1
fi

echo "=============================================="
echo " Git 自动同步工具包 (Linux 版) 安装程序"
echo " 安装目录: ${PREFIX}"
echo " 配置目录: ${CONF_DIR}"
echo "=============================================="

# ---- 1. 程序文件 ----
mkdir -p "$PREFIX"
cp -r "${SRC_DIR}/bin" "${SRC_DIR}/lib" "${SRC_DIR}/systemd" "$PREFIX/"
for f in README.md VERSION.txt LICENSE; do
    [ -f "${SRC_DIR}/${f}" ] && cp "${SRC_DIR}/${f}" "$PREFIX/"
done
[ -d "${SRC_DIR}/docs" ] && cp -r "${SRC_DIR}/docs" "$PREFIX/"

chmod 0755 "$PREFIX"/bin/* "$PREFIX"/lib/*.sh
chmod 0644 "$PREFIX"/systemd/*
echo "[1/5] 程序文件已安装"

# ---- 2. 配置与日志目录 ----
mkdir -p "${CONF_DIR}/repos" "$LOG_DIR"
chmod 0755 "$CONF_DIR"
chmod 0700 "${CONF_DIR}/repos" 2>/dev/null   # 内含 SSH 私钥路径等敏感信息
touch "${CONF_DIR}/mirror_config.txt" "${CONF_DIR}/mirror_settings.txt"
chmod 0644 "${CONF_DIR}/mirror_config.txt" "${CONF_DIR}/mirror_settings.txt"
echo "[2/5] 配置目录已就绪"

# ---- 3. systemd 单元 ----
if [ -d "$UNIT_DIR" ] && command -v systemctl >/dev/null 2>&1; then
    install -m 0644 "${PREFIX}/systemd/git-autosync@.service"      "${UNIT_DIR}/"
    install -m 0644 "${PREFIX}/systemd/git-autosync-fetch.service" "${UNIT_DIR}/"
    if [ ! -f "${UNIT_DIR}/git-autosync-fetch.timer" ]; then
        install -m 0644 "${PREFIX}/systemd/git-autosync-fetch.timer" "${UNIT_DIR}/"
    fi
    systemctl daemon-reload 2>/dev/null || true
    echo "[3/5] systemd 单元已安装"
else
    echo "[3/5] 未检测到 systemd，跳过单元安装（仍可前台运行同步脚本）"
fi

# ---- 4. 命令软链与 man 手册 ----
ln -sf "${PREFIX}/bin/git-autosync" "$BIN_LINK"
MAN_DIR="${MAN_DIR:-/usr/share/man/man1}"
if [ -f "${SRC_DIR}/man/git-autosync.1" ] && [ -d "$(dirname "$MAN_DIR")" ]; then
    mkdir -p "$MAN_DIR"
    gzip -c "${SRC_DIR}/man/git-autosync.1" > "${MAN_DIR}/git-autosync.1.gz"
    chmod 0644 "${MAN_DIR}/git-autosync.1.gz"
    echo "[4/5] 命令已链接：${BIN_LINK}（可用 man git-autosync 查看手册）"
else
    echo "[4/5] 命令已链接：${BIN_LINK}"
fi

# ---- 5. 依赖检查（自动识别发行版，给出对应的安装命令） ----
missing=""
command -v git >/dev/null 2>&1          || missing="${missing} git"
command -v inotifywait >/dev/null 2>&1  || missing="${missing} inotify-tools"

detect_pm() {
    if   command -v dnf     >/dev/null 2>&1; then echo "dnf"
    elif command -v yum     >/dev/null 2>&1; then echo "yum"
    elif command -v apt-get >/dev/null 2>&1; then echo "apt"
    elif command -v zypper  >/dev/null 2>&1; then echo "zypper"
    elif command -v pacman  >/dev/null 2>&1; then echo "pacman"
    elif command -v apk     >/dev/null 2>&1; then echo "apk"
    else echo ""
    fi
}

if [ -n "$missing" ]; then
    PM="$(detect_pm)"
    case "$PM" in
        dnf|yum)  CMD="sudo ${PM} install -y${missing}";;
        apt)      CMD="sudo apt install -y${missing}";;
        zypper)   CMD="sudo zypper install -y${missing}";;
        pacman)   CMD="sudo pacman -S --noconfirm${missing}";;
        apk)      CMD="sudo apk add${missing}";;
        *)        CMD="";
    esac
    echo "[5/5] 缺少依赖：${missing}"
    if [ -n "$CMD" ]; then
        echo "      检测到你的系统，请执行："
        echo "      ${CMD}"
    else
        echo "      未识别到包管理器，请手动安装上述软件包"
    fi
else
    echo "[5/5] 依赖检查通过"
fi

# ---- 6. systemd 可用性提示 ----
if [ ! -d /run/systemd/system ]; then
    echo
    echo "[提示] 当前环境未运行 systemd（Docker 容器 / WSL / 老系统常见）"
    echo "       同步功能仍可用，但服务不会开机自启，需手动运行："
    echo "       sudo ${PREFIX}/bin/git-autosync-sync <仓库名>"
    echo "       定时拉取可用常驻模式："
    echo "       nohup sudo ${PREFIX}/bin/git-autosync-fetch --daemon &"
fi

echo
echo "=============================================="
echo " 安装完成！"
echo " 运行：git-autosync        （交互式主菜单）"
echo "       git-autosync env    （环境自检）"
echo "=============================================="
