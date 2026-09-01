#!/usr/bin/env bash
# ============================================================
# Git 自动同步工具包 (Linux 版) - 卸载脚本
# 用法: sudo bash uninstall.sh
# ============================================================

set -uo pipefail

PREFIX="${PREFIX:-/usr/share/git-autosync}"
CONF_DIR="${CONF_DIR:-/etc/git-autosync}"
UNIT_DIR="${UNIT_DIR:-/etc/systemd/system}"
BIN_LINK="${BIN_LINK:-/usr/bin/git-autosync}"

if [ "$(id -u)" -ne 0 ]; then
    echo "[错误] 请用 root 运行：sudo bash uninstall.sh"
    exit 1
fi

echo "准备卸载 Git 自动同步工具包"

# ---- 1. 停止并移除所有已登记的服务 ----
if command -v systemctl >/dev/null 2>&1; then
    if [ -d "${CONF_DIR}/repos" ]; then
        for conf in "${CONF_DIR}"/repos/*.conf; do
            [ -f "$conf" ] || continue
            name="$(basename "$conf" .conf)"
            echo "  停止服务：git-autosync@${name}"
            systemctl disable --now "git-autosync@${name}.service" 2>/dev/null
            systemctl reset-failed "git-autosync@${name}.service" 2>/dev/null
        done
    fi
    # 停止定时拉取（Restart=always 服务需用 disable --now 才能彻底停掉）
    systemctl disable --now git-autosync-fetch.timer 2>/dev/null
    systemctl reset-failed 2>/dev/null
fi

# ---- 2. 删除 systemd 单元并重新加载 ----
rm -f "${UNIT_DIR}/git-autosync@.service" \
      "${UNIT_DIR}/git-autosync-fetch.service" \
      "${UNIT_DIR}/git-autosync-fetch.timer"
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload 2>/dev/null
    systemctl reset-failed 2>/dev/null
fi

# ---- 3. 删除软链与程序 ----
rm -f "$BIN_LINK"
rm -rf "$PREFIX"
echo "程序文件已删除：${PREFIX}"

# ---- 4. 配置数据处理 ----
if [ -d "$CONF_DIR" ]; then
    echo
    echo "配置目录：${CONF_DIR}（含仓库登记、SMTP 授权码等）"
    read -r -p "是否一并删除配置？[y/N]: " ans
    case "$ans" in
        [yY]*) rm -rf "$CONF_DIR"; echo "配置已删除";;
        *)     echo "配置已保留，重装后可直接继续使用";;
    esac
fi

echo
echo "卸载完成。（各仓库目录内的业务文件未被删除）"
