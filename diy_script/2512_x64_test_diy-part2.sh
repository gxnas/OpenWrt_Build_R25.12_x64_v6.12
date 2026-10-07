#!/bin/bash
#
# OpenWrt DIY script part 2 (After Update feeds / After loading config)
# Adapted for official openwrt/openwrt v25.12.
#

set -e

echo "============开始 DIY2 配置============="

build_date=$(TZ=Asia/Shanghai date "+%Y.%m.%d")
build_name="测试版"

# 默认 LAN 地址
sed -i 's/192.168.1.1/192.168.1.11/g' package/base-files/files/bin/config_generate

# 最大连接数
SYSCTL_FILE="package/base-files/files/etc/sysctl.conf"
grep -q '^net.netfilter.nf_conntrack_max=' "$SYSCTL_FILE" 2>/dev/null || \
    echo 'net.netfilter.nf_conntrack_max=65535' >> "$SYSCTL_FILE"

# ttyd 免账号登录
if [ -f feeds/packages/utils/ttyd/files/ttyd.config ]; then
    sed -i 's#/bin/login#/bin/login -f root#' feeds/packages/utils/ttyd/files/ttyd.config
fi

# x86 型号只显示 CPU 型号
AUTOCORE_FILE=""
for f in \
    package/autocore/files/x86/autocore \
    feeds/packages/utils/autocore/files/x86/autocore \
    package/autocore/files/x86/autocore.lua
do
    if [ -f "$f" ]; then
        AUTOCORE_FILE="$f"
        break
    fi
done

if [ -n "$AUTOCORE_FILE" ]; then
    sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' "$AUTOCORE_FILE" || true
fi

# 设置 Argon 为默认主题（去掉 bootstrap 强制）
find feeds/luci/themes -type f -path '*/uci-defaults/*' -exec \
    sed -i '/set luci.main.mediaurlbase=\/luci-static\/bootstrap/d' {} + 2>/dev/null || true

# 修改 Argon 主题右下角 / 登录页版本信息
if [ -f "$GITHUB_WORKSPACE/personal/argon/footer.ut" ]; then
    cp -f "$GITHUB_WORKSPACE/personal/argon/footer.ut" \
        package/luci-theme-argon/ucode/template/themes/argon/footer.ut
fi
if [ -f "$GITHUB_WORKSPACE/personal/argon/footer_login.ut" ]; then
    cp -f "$GITHUB_WORKSPACE/personal/argon/footer_login.ut" \
        package/luci-theme-argon/ucode/template/themes/argon/footer_login.ut
fi
sed -i "s/OpenWrt_2512_x64_build_name by GXNAS build @R build_date/OpenWrt_2512_x64_${build_name} by GXNAS build @R${build_date}/g" \
    package/luci-theme-argon/ucode/template/themes/argon/footer.ut \
    package/luci-theme-argon/ucode/template/themes/argon/footer_login.ut \
    2>/dev/null || true

# 修改 Liquid 主题右下角版本信息
if [ -f "$GITHUB_WORKSPACE/personal/liquid/footer.ut" ]; then
    cp -f "$GITHUB_WORKSPACE/personal/liquid/footer.ut" \
        package/luci-theme-liquid/ucode/template/themes/liquid/footer.ut
fi
sed -i "s/OpenWrt_2512_x64_build_name by GXNAS build @R build_date/OpenWrt_2512_x64_${build_name} by GXNAS build @R${build_date}/g" \
    package/luci-theme-liquid/ucode/template/themes/liquid/footer.ut \
    2>/dev/null || true

# 自定义 banner
if [ -f "$GITHUB_WORKSPACE/personal/banner" ]; then
    cp -f "$GITHUB_WORKSPACE/personal/banner" package/base-files/files/etc/banner
fi

# 加入作者信息
sed -i "s/DISTRIB_DESCRIPTION='*.*'/DISTRIB_DESCRIPTION='OpenWrt_2512_x64_${build_name}'/g"  package/base-files/files/etc/openwrt_release
sed -i "s/DISTRIB_REVISION='*.*'/DISTRIB_REVISION=' by GXNAS build @R${build_date}'/g" package/base-files/files/etc/openwrt_release
sed -i "s/OPENWRT_RELEASE=\"*.*\"/OPENWRT_RELEASE=\"OpenWrt_2512_x64_${build_name} by GXNAS build @R${build_date}\"/g" package/base-files/files/usr/lib/os-release


# 修复 netdata 自动启动
if [ -f package/luci-app-netdata/root/etc/init.d/netdata ]; then
  chmod +x package/luci-app-netdata/root/etc/init.d/netdata
fi
mkdir -p package/base-files/files/etc/rc.d
ln -sf ../init.d/netdata package/base-files/files/etc/rc.d/S99netdata 2>/dev/null || true
mkdir -p package/base-files/files/etc/netdata
cat << 'EOF' > package/base-files/files/etc/netdata/netdata.conf
[global]
    run as user = root
    memory mode = ram
[cloud]
    enabled = no
EOF
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-netdata
#!/bin/sh
[ -x /etc/init.d/netdata ] && /etc/init.d/netdata enable && /etc/init.d/netdata restart
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-netdata


# 第三方 Makefile：git.openwrt.org -> github.com/openwrt
find package -type f \( -name "Makefile" -o -name "*.mk" \) \
    -exec sed -i 's#https://git.openwrt.org/#https://github.com/openwrt/#g' {} + 2>/dev/null || true

# ---------- 修复第三方插件 apk 非法版本号 ----------
echo "修复第三方插件 apk 非法版本号..."
fix_pkg_version() {
  local mf="$1"
  [ -f "$mf" ] || return 0
  if grep -qE '^PKG_VERSION:=.*-[0-9]{8}' "$mf"; then
    echo "修复版本: $mf"
    sed -i -E 's/^(PKG_VERSION:=.*)(-)([0-9]{8})/\1.\3/' "$mf"
    grep '^PKG_VERSION' "$mf" || true
  fi
  if grep -qE '^PKG_VERSION:=.*-(beta|rbeta|alpha|rc[0-9]*)' "$mf"; then
    echo "清理 beta 后缀: $mf"
    sed -i -E 's/^(PKG_VERSION:=.*)-(beta|rbeta|alpha|rc[0-9]*)/\1/' "$mf"
    grep '^PKG_VERSION' "$mf" || true
  fi
}
find package -name Makefile 2>/dev/null | while read -r mf; do
  fix_pkg_version "$mf"
done

# 单独处理 luci-app-adguardhome
if [ -f package/luci-app-adguardhome/Makefile ]; then
  echo "===== luci-app-adguardhome Makefile 版本信息 ====="
  grep -E '^(PKG_NAME|PKG_VERSION|PKG_RELEASE|LUCI_VERSION)' \
    package/luci-app-adguardhome/Makefile || true
  sed -i -E \
    's/^(PKG_VERSION:=)([0-9]+\.[0-9]+)-([0-9]{8})/\1\2.\3/' \
    package/luci-app-adguardhome/Makefile
  if grep -q '1\.8-20221120' \
    package/luci-app-adguardhome/Makefile 2>/dev/null; then
    sed -i 's/1\.8-20221120/1.8.20221120/g' \
      package/luci-app-adguardhome/Makefile
  fi
  echo "===== 修复后 ====="
  grep -E '^(PKG_NAME|PKG_VERSION|PKG_RELEASE|LUCI_VERSION)' \
    package/luci-app-adguardhome/Makefile || true
fi

echo "=============DIY2 配置完成============"
