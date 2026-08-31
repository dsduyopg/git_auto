#!/usr/bin/env bash
# ============================================================
# 打包脚本：生成 tar.gz 与 rpm 两个 Linux 发布包
# 用法: bash build.sh
# 产物: dist/git-autosync-2.15.tar.gz
#       dist/git-autosync-2.15-1.*.noarch.rpm
# ============================================================

set -euo pipefail

NAME="git-autosync"
VERSION="2.15"
PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJ_DIR}/build"
DIST_DIR="${PROJ_DIR}/dist"

echo "=============================================="
echo " 打包 ${NAME} v${VERSION}"
echo "=============================================="

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# ---- 1. 组装源码目录（tar.gz 的根目录） ----
SRC="${BUILD_DIR}/${NAME}-${VERSION}"
mkdir -p "$SRC"
cp -r "${PROJ_DIR}/bin"      "$SRC/"
cp -r "${PROJ_DIR}/lib"      "$SRC/"
cp -r "${PROJ_DIR}/systemd"  "$SRC/"
cp -r "${PROJ_DIR}/packaging" "$SRC/" 2>/dev/null || true
[ -d "${PROJ_DIR}/docs" ] && cp -r "${PROJ_DIR}/docs" "$SRC/"
[ -d "${PROJ_DIR}/man" ]  && cp -r "${PROJ_DIR}/man"  "$SRC/"
for f in README.md VERSION.txt LICENSE install.sh uninstall.sh; do
    [ -f "${PROJ_DIR}/${f}" ] && cp "${PROJ_DIR}/${f}" "$SRC/"
done
chmod 0755 "$SRC"/bin/* "$SRC"/install.sh "$SRC"/uninstall.sh
chmod 0644 "$SRC"/lib/*.sh "$SRC"/systemd/*

# ---- 2. 生成 tar.gz ----
echo "[1/3] 生成 tar.gz ..."
tar -czf "${DIST_DIR}/${NAME}-${VERSION}.tar.gz" -C "$BUILD_DIR" "${NAME}-${VERSION}"
echo "      -> ${DIST_DIR}/${NAME}-${VERSION}.tar.gz"

# ---- 3. 准备 rpmbuild 环境 ----
echo "[2/3] 准备 rpmbuild 环境 ..."
if ! command -v rpmbuild >/dev/null 2>&1; then
    echo "[错误] 未找到 rpmbuild，请先安装："
    echo "       sudo dnf install -y rpm-build rpmdevtools"
    exit 1
fi
command -v rpmdev-setuptree >/dev/null 2>&1 && rpmdev-setuptree || mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

cp "${DIST_DIR}/${NAME}-${VERSION}.tar.gz" ~/rpmbuild/SOURCES/
cp "${PROJ_DIR}/packaging/${NAME}.spec"    ~/rpmbuild/SPECS/

# ---- 4. 构建 rpm ----
echo "[3/3] 构建 rpm ..."
rpmbuild -bb ~/rpmbuild/SPECS/${NAME}.spec 2>&1 | tail -n 25

RPM_OUT="$(find ~/rpmbuild/RPMS -name "${NAME}-${VERSION}-*.rpm" | head -n1)"
if [ -n "$RPM_OUT" ]; then
    cp "$RPM_OUT" "$DIST_DIR"/
    echo
    echo "=============================================="
    echo " 打包完成，产物："
    ls -lh "$DIST_DIR"
    echo "=============================================="
    echo
    echo "安装方式："
    echo "  rpm  : sudo dnf install -y ${DIST_DIR}/$(basename "$RPM_OUT")"
    echo "  tarball: tar -xzf ${DIST_DIR}/${NAME}-${VERSION}.tar.gz && cd ${NAME}-${VERSION} && sudo bash install.sh"
else
    echo "[错误] rpm 构建失败"
    exit 1
fi
