# ============================================================
# i18n - Internationalization layer for git-autosync
#
# Default language: English (fedora/i18n friendly).
# Users may switch to Chinese at any time:
#   git-autosync lang zh      # switch to Chinese
#   git-autosync lang en      # switch back to English (default)
#
# Preference is stored in /etc/git-autosync/ui_lang (en | zh)
# and can be overridden per-run with GIT_AUTOSYNC_LANG=en|zh
# ============================================================

: "${CONF_DIR:=/etc/git-autosync}"
UI_LANG_FILE="${CONF_DIR}/ui_lang"

# ---- 1. Resolve language: env var > config file > default(en) ----
_i18n_read_pref() {
    if [ -n "${GIT_AUTOSYNC_LANG:-}" ]; then
        printf '%s' "$GIT_AUTOSYNC_LANG"
        return
    fi
    [ -r "$UI_LANG_FILE" ] && tr -d ' \t\r\n' < "$UI_LANG_FILE" 2>/dev/null
}

case "$(_i18n_read_pref)" in
    zh|zh_*|ZH|cn|CN|Chinese|中文) GIT_AUTOSYNC_LANG="zh" ;;
    *)                             GIT_AUTOSYNC_LANG="en" ;;
esac
export GIT_AUTOSYNC_LANG

# ---- 2. Translation table: Chinese source string -> English ----
# Requires bash 4+ (associative arrays). Falls back to pass-through.
if declare -A I18N 2>/dev/null; then
    # -- output level prefixes --
    I18N["[信息]"]="[INFO]"
    I18N["[成功]"]="[OK]"
    I18N["[错误]"]="[ERROR]"
    I18N["[警告]"]="[WARN]"

    # -- generic prompts --
    I18N["按回车继续..."]="Press Enter to continue..."
    I18N["确定继续？"]="Continue?"
    I18N["确定继续?"]="Continue?"
    I18N["是否覆盖？"]="Overwrite?"
    I18N["是否立即克隆一次？"]="Clone now?"
    I18N["是否连仓库目录一起删除？此操作不可恢复！"]="Also delete the repository directory? This cannot be undone!"
    I18N["无效选择"]="Invalid choice"
    I18N["输入无效"]="Invalid input"
    I18N["不能为空"]="Cannot be empty"
    I18N["路径不能为空"]="Path cannot be empty"
    I18N["地址和目录不能为空"]="URL and directory cannot be empty"
    I18N["远端地址不能为空"]="Remote URL cannot be empty"
    I18N["已取消"]="Cancelled"

    # -- menu prompts --
    I18N["请选择 [0-13]: "]="Choose [0-13]: "
    I18N["请选择 [0-12]: "]="Choose [0-12]: "
    I18N["请选择编号: "]="Select number: "
    I18N["选择: "]="Choose: "
    I18N["选择 [1/2]（默认 1）: "]="Choose [1/2] (default 1): "
    I18N["选择操作（直接回车返回）: "]="Choose action (press Enter to go back): "
    I18N["选择编号（直接回车用第 1 个，或输入完整路径）: "]="Select number (Enter for the first, or type a full path): "

    # -- new-repo wizard --
    I18N["第 1 步：要同步的本地文件夹路径"]="Step 1: local folder path to sync"
    I18N["第 1.5 步：要排除的目录/文件（逗号分隔，可留空）"]="Step 1.5: directories/files to exclude (comma-separated, optional)"
    I18N["第 2 步：选择平台"]="Step 2: choose platform"
    I18N["第 3 步：远端 SSH 地址（如 git@github.com:user/repo.git）"]="Step 3: remote SSH URL (e.g. git@github.com:user/repo.git)"
    I18N["  1) Gitee  （默认分支 master）"]="  1) Gitee  (default branch: master)"
    I18N["  2) GitHub （默认分支 main）"]="  2) GitHub (default branch: main)"
    I18N["  确认分支名"]="  Confirm branch name"
    I18N["分支名"]="Branch name"
    I18N["远端 SSH 地址"]="Remote SSH URL"
    I18N["拉取到哪个本地目录"]="Local directory to pull into"
    I18N["拉取间隔（分钟，1-1440）"]="Pull interval (minutes, 1-1440)"

    # -- SSH --
    I18N["第 1 项：选择 SSH 私钥"]="Item 1: choose SSH private key"
    I18N["第 2 项：Git 提交身份"]="Item 2: Git commit identity"
    I18N["SSH 私钥路径（可留空用默认密钥）"]="SSH private key path (leave empty to use the default key)"
    I18N["未扫描到私钥，请输入私钥完整路径（可留空使用默认 SSH 配置）"]="No private key found; enter the full path (leave empty to use the default SSH config)"
    I18N["生成 SSH 密钥（Gitee / GitHub 通用）"]="Generate SSH key (works for Gitee / GitHub)"
    I18N["请输入邮箱（用于密钥注释）"]="Enter email (used as the key comment)"
    I18N["密钥已生成："]="Key generated: "
    I18N["已存在密钥："]="Key already exists: "
    I18N["密钥生成失败"]="Key generation failed"
    I18N["未找到 ssh-keygen，请先安装 openssh-clients"]="ssh-keygen not found; please install openssh-clients"
    I18N["请把下面这段公钥添加到 Gitee / GitHub（SSH Keys）："]="Add the following public key to Gitee / GitHub (SSH Keys):"
    I18N["Gitee : 设置 -> SSH公钥"]="Gitee : Settings -> SSH Keys"
    I18N["使用私钥："]="Using key: "

    # -- repository operations --
    I18N["尚未登记任何仓库"]="No repository registered yet"
    I18N["已登记的仓库："]="Registered repositories:"
    I18N["已登记仓库"]="Registered repositories"
    I18N["已登记到："]="Registered to: "
    I18N["已写入仓库配置："]="Repo config written: "
    I18N["（服务名："]=" (service: "
    I18N["仓库路径："]="Repository path: "
    I18N["仓库目录："]="Repository directory: "
    I18N["目录不存在，是否创建 "]="Directory does not exist. Create "
    I18N["初始化 git 仓库..."]="Initializing git repository..."
    I18N["完成！"]="Done! "
    I18N[" 将实时自动同步到 "]=" will now sync in real time to "
    I18N["已自动改用 443 端口："]="Auto-switched to port 443: "
    I18N["该远端已登记，将更新记录"]="This remote is already registered; the record will be updated"
    I18N["查看日志："]="View logs: "
    I18N["查看状态：git-autosync status"]="View status: git-autosync status"
    I18N["首次推送失败，服务运行中会自动重试"]="First push failed; will retry automatically while the service is running"
    I18N["推送失败，服务运行中会自动重试"]="Push failed; will retry automatically while the service is running"

    # -- service operations --
    I18N["服务已启动并设为开机自启："]="Service started and enabled at boot: "
    I18N["服务启动失败，请查看："]="Service failed to start; check: "
    I18N["服务状态"]="Service status"
    I18N["已启动 "]="Started "
    I18N["已停止 "]="Stopped "
    I18N["已重启 "]="Restarted "
    I18N["已设开机自启 "]="Enabled at boot: "
    I18N["已取消开机自启 "]="Disabled at boot: "
    I18N["  s) 启动   t) 停止   r) 重启   e) 开机自启   d) 取消自启"]="  s) start   t) stop   r) restart   e) enable   d) disable"
    I18N["无 systemd，无法查询服务状态"]="No systemd; cannot query service status"
    I18N["当前环境无 systemd，已生成配置但未启动服务"]="No systemd detected: config written but the service was not started"
    I18N["可手动前台运行："]="Can run in the foreground manually: "
    I18N["或设为后台常驻："]="Or run as a background daemon: "
    I18N["无 systemd，可用常驻模式："]="No systemd; daemon mode available: "

    # -- repair / rebuild / uninstall --
    I18N["修复所有同步服务"]="Repair all sync services"
    I18N["已修复并重启"]="Repaired and restarted "
    I18N["个服务"]=" service(s)"
    I18N["彻底重建所有服务"]="Rebuild all services"
    I18N["将停止并重建全部同步服务（仓库数据和配置保留）"]="This will stop and rebuild all sync services (repository data and configs are kept)"
    I18N["已彻底重建"]="Rebuilt "
    I18N["卸载服务："]="Uninstall service: "
    I18N["服务配置已删除（仓库文件未删除）"]="Service config deleted (repository files kept)"
    I18N["停止服务失败："]="Failed to stop service: "
    I18N["禁用服务失败："]="Failed to disable service: "
    I18N["未检测到 systemd，跳过服务停用"]="systemd not detected; skipping service stop"
    I18N["配置文件不存在："]="Config file does not exist: "
    I18N["删除配置文件失败："]="Failed to delete config file: "
    I18N["仓库名不合法："]="Invalid repository name: "
    I18N["配置缺少 repo_path"]="Config is missing repo_path"
    I18N["已删除："]="Deleted: "

    # -- scheduled pull --
    I18N["定时拉取服务"]="Scheduled pull service"
    I18N["  1) 启用定时拉取（开机自启 + 定时触发）"]="  1) Enable scheduled pull (auto-start + timer)"
    I18N["  2) 停用定时拉取"]="  2) Disable scheduled pull"
    I18N["  3) 设置拉取间隔（分钟）"]="  3) Set pull interval (minutes)"
    I18N["  4) 立即执行一次拉取"]="  4) Run a pull now"
    I18N["定时拉取已启用"]="Scheduled pull enabled"
    I18N["定时拉取已停用"]="Scheduled pull disabled"
    I18N["当前状态：已启用"]="Current status: enabled"
    I18N["当前状态：未启用"]="Current status: disabled"
    I18N["间隔已设为"]="Interval set to "
    I18N["分钟"]=" minutes"
    I18N["启用失败"]="Failed to enable"
    I18N["首次尝试拉取远端（空仓库属正常）..."]="First pull attempt (an empty repository is normal)..."

    # -- remove tracked directory --
    I18N["移除推送目录："]="Remove directory from tracking: "
    I18N["该操作会把目录从 Git 跟踪中移除并写入 .gitignore，本地文件会保留"]="This removes the directory from Git tracking and adds it to .gitignore; local files are kept"
    I18N["请输入要移除的目录/文件（相对仓库路径，如 node_modules 或 大文件.zip）"]="Enter the directory/file to remove (path relative to the repo, e.g. node_modules or bigfile.zip)"
    I18N["已移除推送："]="Removed from tracking: "
    I18N["（本地文件保留）"]=" (local files kept)"
    I18N["已排除（本地文件保留）："]="Excluded (local files kept): "
    I18N["auto-sync: 移除推送 "]="auto-sync: stop tracking "

    # -- privileges / dependencies --
    I18N["该操作需要 root 权限（需写入"]="This operation requires root privileges (needs write access to "
    I18N["请先安装 git"]="Please install git first"
    I18N["缺少依赖命令："]="Missing required command: "
    I18N["已清理残留锁："]="Removed stale lock: "
    I18N["秒未变动)"]="s unchanged)"
    I18N["创建失败"]="Creation failed"
    I18N["未知命令："]="Unknown command: "
    I18N["（用 git-autosync help 查看用法）"]=" (run 'git-autosync help' for usage)"
    I18N["(开机自启)"]=" (auto-start at boot)"

    # -- realtime sync daemon (git-autosync-sync) --
    I18N["Git 实时同步启动："]="Git realtime sync started: "
    I18N["（分支 "]=" (branch "
    I18N["，防抖 "]=", debounce "
    I18N["s）"]="s)"
    I18N["启动时执行一次完整同步..."]="Running an initial full sync at startup..."
    I18N["已提交："]="Committed: "
    I18N["已推送到 "]="Pushed to "
    I18N["推送成功 -> "]="Push succeeded -> "
    I18N["推送失败(第 "]="Push failed (attempt "
    I18N[" 次)："]="): "
    I18N["推送失败，超过重试次数，将在下次变化时重试"]="Push failed after max retries; will retry on the next change"
    I18N["推送失败，超过重试次数。最后一次错误: "]="Push failed after max retries. Last error: "
    I18N["无实际文件变动，跳过提交"]="No actual file changes; skipping commit"
    I18N["开始实时监听目录："]="Started watching directory: "
    I18N["找不到仓库配置："]="Repository config not found: "
    I18N["配置缺少 repo_path："]="Config is missing repo_path: "
    I18N["目录不存在："]="Directory does not exist: "
    I18N["该目录不是 git 仓库："]="Not a git repository: "
    I18N["未配置远程仓库 "]="Remote not configured: "
    I18N["未找到 git 命令，请先安装 Git"]="git command not found; please install Git"
    I18N["未找到 inotifywait，无法实时监听。请安装 inotify-tools："]="inotifywait not found; cannot watch in real time. Please install inotify-tools: "
    I18N["git add 失败"]="git add failed"
    I18N["git commit 失败"]="git commit failed"
    I18N["[Git同步成功] "]="[Git sync OK] "
    I18N["[Git同步失败] "]="[Git sync FAILED] "
    I18N["用法: "]="Usage: "

    # -- mirror fetch (git-autosync-fetch) --
    I18N["change fetcher 启动（常驻模式）间隔: "]="Mirror fetcher started (daemon mode), interval: "
    I18N["fetch 失败 "]="Fetch failed: "
    I18N["克隆失败 "]="Clone failed: "
    I18N["已克隆 "]="Cloned "
    I18N["已更新 "]="Updated "
    I18N["拉取成功: "]="Pull succeeded: "
    I18N["拉取失败: "]="Pull failed: "
    I18N["找不到登记表："]="Registry file not found: "
    I18N["（可先用 git-autosync 的『新建云端镜像拉取』登记）"]=" (register one first with 'git-autosync mirror')"
    I18N["----- 新一轮检测 -----"]="----- new polling round -----"
    I18N["未找到 git 命令"]="git command not found"
    I18N["未找到 SSH 私钥，且登记表未逐条指定密钥"]="No SSH key found and no per-entry key in the registry"
    I18N["本轮完成，共处理 "]="Round finished, processed "
    I18N[" 个镜像"]=" mirror(s)"
    I18N["登记表: "]="Registry: "
    I18N["  清理未跟踪文件: "]="  clean untracked files: "

    # -- language switcher (added by this layer) --
    I18N["语言设置"]="Language"
    I18N["当前语言"]="Current language"
    I18N["已切换为中文"]="Switched to Chinese"
    I18N["已切换为英文"]="Switched to English"
    I18N["用法: git-autosync lang {en|zh}"]="Usage: git-autosync lang {en|zh}"

    # -- main script: sub-command titles and language menu (added in 2.15-9) --
    I18N["新建自动推送仓库（本地文件夹 → 云端，实时自动提交推送）"]="New auto-push repository (local folder -> cloud, real-time commit and push)"
    I18N["新建云端镜像拉取（云端 → 本地，定时自动更新）"]="New cloud mirror pull (cloud -> local, clone now plus scheduled update)"
    I18N["与 systemd 单元），请用 sudo 运行"]="and systemd units). Please run with sudo"
    I18N["保存失败，请用 root 运行："]="Failed to save; run as root: "
    I18N["保存失败，请用："]="Failed to save; run: "
    I18N["当前语言："]="Current language: "
    I18N["中文 (zh)"]="Chinese (zh)"
    I18N["Language / 语言"]="Language"
    I18N["当前语言：中文 (zh)"]="Current language: Chinese (zh)"
    I18N["  2) 中文 / Chinese"]="  2) Chinese"
    I18N["  0) Back / 返回"]="  0) Back"
    I18N["Invalid choice / 无效选择"]="Invalid choice"
    I18N["  0) 返回"]="  0) Back"
    I18N["（"]="("
    I18N["）"]=")"
    I18N["："]=": "
    I18N["，"]=", "
    I18N["；"]="; "
    I18N["？"]="?"
    I18N["！"]="!"
    I18N["　"]=" "
    I18N["…"]="..."
    I18N["→"]="->"

    # ---- sort keys longest-first so longer phrases win ----
    I18N_KEYS=()
    while IFS= read -r _k; do
        I18N_KEYS+=("$_k")
    done < <(
        for _k in "${!I18N[@]}"; do
            printf '%d\t%s\n' "${#_k}" "$_k"
        done | sort -rn | cut -f2-
    )

    # ---- translate a string (Chinese -> English) ----
    tr_msg() {
        local s="$1" k
        if [ "$GIT_AUTOSYNC_LANG" != "en" ]; then
            printf '%s' "$s"
            return 0
        fi
        for k in "${I18N_KEYS[@]}"; do
            case "$s" in
                *"$k"*) s="${s//"$k"/${I18N[$k]}}" ;;
            esac
        done
        printf '%s' "$s"
    }
else
    # bash without associative arrays: keep original text
    tr_msg() { printf '%s' "$1"; }
fi

# Short alias
T() { tr_msg "$1"; }

# ---- 3. Switch / persist UI language ----
# usage: set_ui_lang en|zh
set_ui_lang() {
    case "${1:-}" in
        zh|zh_CN|cn|CN|中文)
            printf 'zh\n' > "$UI_LANG_FILE" 2>/dev/null && GIT_AUTOSYNC_LANG="zh"
            ;;
        en|en_US|EN|English)
            printf 'en\n' > "$UI_LANG_FILE" 2>/dev/null && GIT_AUTOSYNC_LANG="en"
            ;;
        *)
            return 1
            ;;
    esac
}
