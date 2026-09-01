# 注意：不要覆盖 _prefix 宏，否则 _bindir / _unitdir / _sysconfdir 等
#       标准宏都会被连带改到错误路径。这里改用自定义宏 install_dir。
# 遵循 Fedora Packaging Guidelines：使用标准宏，不安装到 /opt。
%global install_dir %{_datadir}/git-autosync
%global _rpmlintrc %{name}.rpmlintrc

# _unitdir 宏由 systemd-rpm-macros 包提供（见 BuildRequires）。
# 若构建环境未安装该包，宏不会展开，这里回退到 systemd 标准单元目录，
# 保证跨环境可构建。
%if %{undefined _unitdir}
%global _unitdir /usr/lib/systemd/system
%endif

Name:           git-autosync
Version:        2.15
Release:        7%{?dist}
Summary:        Git automatic synchronization toolkit for local folders

License:        MIT
URL:            https://github.com/dsduyopg/git_auto
Source0:        https://github.com/dsduyopg/git_auto/releases/download/v%{version}/%{name}-%{version}.tar.gz
Source1:        git-autosync.rpmlintrc
# SHA-256 of the upstream source tarball (verify before building):
# c4514784b015e49eb4369690213e86ce93e814ed7980717112a8ba1ea55f4af0

BuildArch:      noarch

Requires:       bash
Requires:       git
Requires:       inotify-tools
Requires:       systemd
Requires:       python3
Requires:       logrotate
BuildRequires:  systemd-rpm-macros
%{?systemd_requires}

%description
Git AutoSync is a Linux tool that automatically syncs local folders to Gitee /
GitHub repositories. It is a systemd + inotify port of the original Windows
(PowerShell + NSSM) design.

Features:
- Real-time two-way sync (watch -> commit -> push / pull)
- systemd timer for periodic pull
- One-shot service install / repair / rebuild / uninstall
- Email notification on success / failure (optional, off by default)
- Auto-cleanup of stale index.lock to avoid sync stalls
- Runs on RHEL / CentOS / Fedora / AlmaLinux / Rocky

---------------------------------------------------------------------------
Git 自动同步工具包（Linux 版）：自动把本地文件夹变更同步到 Gitee / GitHub，
或把云端仓库定时拉取到本地，0 基础可用。基于原 Windows 版（PowerShell +
NSSM）移植到 systemd + inotify。

%prep
%setup -q

%build
# 纯 Shell 脚本，无需编译

%check
# 语法自检：确保所有 shell 脚本无语法错误
for f in bin/* lib/*.sh; do
    bash -n "$f" || { echo "syntax error: $f"; exit 1; }
done

%install
rm -rf %{buildroot}

# 程序主体（LICENSE 由 license 宏单独安装，此处不复制以免文件重复）
mkdir -p %{buildroot}%{install_dir}
cp -r bin lib systemd %{buildroot}%{install_dir}/
cp README.md VERSION.txt %{buildroot}%{install_dir}/
cp install.sh uninstall.sh %{buildroot}%{install_dir}/
if [ -d docs ]; then cp -r docs %{buildroot}%{install_dir}/; fi
chmod 0755 %{buildroot}%{install_dir}/bin/*
chmod 0644 %{buildroot}%{install_dir}/lib/*.sh
chmod 0644 %{buildroot}%{install_dir}/systemd/*

# logrotate 配置（防止 /var/log/git-autosync 下日志无限增长）
mkdir -p %{buildroot}%{_sysconfdir}/logrotate.d
install -m 0644 logrotate/git-autosync %{buildroot}%{_sysconfdir}/logrotate.d/git-autosync

# 命令入口
mkdir -p %{buildroot}%{_bindir}
ln -sf %{install_dir}/bin/git-autosync %{buildroot}%{_bindir}/git-autosync

# systemd 单元
mkdir -p %{buildroot}%{_unitdir}
cp systemd/git-autosync@.service      %{buildroot}%{_unitdir}/
cp systemd/git-autosync-fetch.service %{buildroot}%{_unitdir}/
cp systemd/git-autosync-fetch.timer   %{buildroot}%{_unitdir}/

# 配置与日志目录
mkdir -p %{buildroot}%{_sysconfdir}/git-autosync/repos
mkdir -p %{buildroot}%{_localstatedir}/log/git-autosync

# man 手册页
mkdir -p %{buildroot}%{_mandir}/man1
gzip -c man/git-autosync.1 > %{buildroot}%{_mandir}/man1/git-autosync.1.gz
chmod 0644 %{buildroot}%{_mandir}/man1/git-autosync.1.gz

%files
%license LICENSE
%{install_dir}
%{_bindir}/git-autosync
%{_unitdir}/git-autosync@.service
%{_unitdir}/git-autosync-fetch.service
%{_unitdir}/git-autosync-fetch.timer
%dir %{_sysconfdir}/git-autosync
%dir %{_sysconfdir}/git-autosync/repos
%dir %{_localstatedir}/log/git-autosync
%{_mandir}/man1/git-autosync.1.gz
%config(noreplace) %{_sysconfdir}/logrotate.d/git-autosync

%post
%systemd_post git-autosync-fetch.service git-autosync-fetch.timer
echo "git-autosync has been installed."
echo "  Run: sudo git-autosync          # interactive main menu"
echo "       sudo git-autosync env      # environment check"

%preun
if [ "$1" -eq 0 ]; then
    # 卸载前停止并禁用所有已登记的 per-repo 实例
    for c in %{_sysconfdir}/git-autosync/repos/*.conf; do
        [ -f "$c" ] || continue
        n=$(basename "$c" .conf)
        systemctl stop "git-autosync@${n}.service" >/dev/null 2>&1 || :
        systemctl disable "git-autosync@${n}.service" >/dev/null 2>&1 || :
    done
fi
%systemd_preun git-autosync-fetch.service git-autosync-fetch.timer

%postun
%systemd_postun_with_restart git-autosync-fetch.service git-autosync-fetch.timer

%changelog
* Tue Sep 01 2026 wowsony <dsduyopg@github.com> - 2.15-7
- i18n: default English UI with optional Chinese mode
- man page translated to English, install paths updated
- English Summary
- rpmlint: suppress false spelling-error warnings
* Tue Sep 01 2026 wowsony <dsduyopg@github.com> - 2.15-1
- Linux 版首发，移植自 Windows v2.15
- 遵循 Fedora Packaging Guidelines：改用 /usr/share 标准路径，补充 logrotate 配置
- systemd 服务替代 NSSM，inotifywait 替代 FileSystemWatcher
- 含完整中文使用手册与 man 手册页
- 提供中英双语 %%description，便利国际化评审
