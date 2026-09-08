# Changelog / 更新日志

## v2.15-10（RPM Release 10，2026-09-02）

- 重新打包发布：RPM、Source RPM、tar.gz 同步构建（rpm release 10）
- 修正打包元数据与 rpmlintrc，RHEL 系安装更干净
- 修复文档与 man 中的仓库地址（统一指向本仓库）

## v2.15-7（2026-09-01）

- man page 与 RPM Summary 改为英文，%post 脚本英文化
- 打包 rpmlintrc，去除打包告警

## v2.15-6（2026-08-31）

- i18n：界面 / 提示 / 日志默认英文，支持 `lang` 切换中文
- 发布 `2.15-6.el10` 版本

## v2.15 早期

- 修复 4 个真实 bug
- 服务管理：一键安装 / 修复 / 重建 / 卸载
- Linux 发行版全套打包（RPM / tar.gz / systemd / man / docs）

---

## Windows 版 v2.16（2026-08-31）

- Windows 工具包（PowerShell + NSSM）发布 v2.16
- 修复 man 页中文编码问题
