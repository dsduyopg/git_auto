# 注意：不要覆盖 _prefix 宏，否则 _bindir / _unitdir / _sysconfdir 等
#       标准宏都会被连带改到错误路径。这里改用自定义宏 install_dir。
%global install_dir /opt/git-autosync

Name:           git-autosync
Version:        2.15
Release:        1%{?dist}
Summary:        Git 自动同步工具包（本地文件夹自动同步 Gitee/GitHub）

License:        MIT
URL:            https://github.com/dsduyopg/linux_heima
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch

Requires:       bash
Requires:       git
Requires:       inotify-tools
Requires:       systemd
Requires:       python3

%description
Git 自动同步工具包 Linux 版，移植自 Windows v2.15（PowerShell + NSSM）。

让文件夹自动同步 Gitee / GitHub，或把云端仓库定时拉取到本地，0 基础可用。

技术映射（相对 Windows 原版）：
  NSSM 服务注册      ->  systemd 服务（每仓库一个 git-autosync@<名称>.service）
  FileSystemWatcher  ->  inotifywait 实时监听（3 秒防抖合并）
  定时拉取服务        ->  systemd timer（git-autosync-fetch.timer）
  .NET SmtpClient    ->  python3 smtplib（邮件通知，可选）

功能：
  1. 本地文件夹自动推送 Gitee / GitHub
  2. 云端仓库镜像定时拉取
  3. 服务一键安装 / 修复 / 重建 / 卸载
  4. 新建仓库时可排除目录/文件；已有仓库可移除推送目录
  5. 自动检测并清理残留 index.lock，避免同步卡死
  6. 邮件通知：同步成功/失败自动发邮件，可随时开关（默认关闭）

%prep
%setup -q

%build
# 纯 Shell 脚本，无需编译

%install
rm -rf %{buildroot}

# 程序主体
mkdir -p %{buildroot}%{install_dir}
cp -r bin lib systemd %{buildroot}%{install_dir}/
cp README.md VERSION.txt LICENSE %{buildroot}%{install_dir}/
cp install.sh uninstall.sh %{buildroot}%{install_dir}/
if [ -d docs ]; then cp -r docs %{buildroot}%{install_dir}/; fi
chmod 0755 %{buildroot}%{install_dir}/bin/*
chmod 0644 %{buildroot}%{install_dir}/lib/*.sh
chmod 0644 %{buildroot}%{install_dir}/systemd/*

# 命令入口（/usr/bin/git-autosync -> /opt/git-autosync/bin/git-autosync）
mkdir -p %{buildroot}%{_bindir}
ln -sf %{install_dir}/bin/git-autosync %{buildroot}%{_bindir}/git-autosync

# systemd 单元（/usr/lib/systemd/system）
mkdir -p %{buildroot}%{_unitdir}
cp systemd/git-autosync@.service      %{buildroot}%{_unitdir}/
cp systemd/git-autosync-fetch.service %{buildroot}%{_unitdir}/
cp systemd/git-autosync-fetch.timer   %{buildroot}%{_unitdir}/

# 配置与日志目录（/etc/git-autosync、/var/log/git-autosync）
mkdir -p %{buildroot}%{_sysconfdir}/git-autosync/repos
mkdir -p %{buildroot}%{_localstatedir}/log/git-autosync

# man 手册页
mkdir -p %{buildroot}%{_mandir}/man1
gzip -c man/git-autosync.1 > %{buildroot}%{_mandir}/man1/git-autosync.1.gz
chmod 0644 %{buildroot}%{_mandir}/man1/git-autosync.1.gz

%files
%license LICENSE
%doc README.md VERSION.txt
%{install_dir}
%{_bindir}/git-autosync
%{_unitdir}/git-autosync@.service
%{_unitdir}/git-autosync-fetch.service
%{_unitdir}/git-autosync-fetch.timer
%dir %{_sysconfdir}/git-autosync
%dir %{_sysconfdir}/git-autosync/repos
%dir %{_localstatedir}/log/git-autosync
%{_mandir}/man1/git-autosync.1.gz

%post
systemctl daemon-reload >/dev/null 2>&1 || :
echo "Git 自动同步工具包已安装"
echo "  运行：sudo git-autosync          # 交互式主菜单"
echo "       sudo git-autosync env      # 环境自检"
exit 0

%preun
if [ "$1" = "0" ]; then
    # 卸载前停止所有已登记服务
    for c in %{_sysconfdir}/git-autosync/repos/*.conf; do
        [ -f "$c" ] || continue
        n=$(basename "$c" .conf)
        systemctl stop "git-autosync@${n}.service" >/dev/null 2>&1 || :
        systemctl disable "git-autosync@${n}.service" >/dev/null 2>&1 || :
    done
    systemctl stop git-autosync-fetch.timer >/dev/null 2>&1 || :
    systemctl disable git-autosync-fetch.timer >/dev/null 2>&1 || :
fi
exit 0

%postun
systemctl daemon-reload >/dev/null 2>&1 || :
exit 0

%changelog
* Mon Aug 31 2026 wowsony <dsduyopg@github.com> - 2.15-1
- Linux 版首发，移植自 Windows v2.15
- systemd 服务替代 NSSM，inotifywait 替代 FileSystemWatcher
- 保留全部原功能：实时推送、定时拉取、服务管理、排除目录、index.lock 清理、邮件通知
