#!/bin/bash
#
# OpenWrt DIY script part 1 (Before feeds update)
# Adapted for official openwrt/openwrt v25.12.
#

set -e

echo "============开始 DIY1 配置============="

# ---------- 修复 intel-microcode 构建报错 ----------
MF="package/firmware/intel-microcode/Makefile"
if [ -f "$MF" ]; then
  awk '
    /mkdir.*intel-ucode-ipkg/ && !done {
      print "\trm -rf $(PKG_BUILD_DIR)/intel-ucode-ipkg"
      print "\tmkdir -p $(PKG_BUILD_DIR)/intel-ucode-ipkg"
      done=1
      next
    }
    { print }
  ' "$MF" > "$MF.tmp" && mv "$MF.tmp" "$MF"
  echo "已修复 intel-microcode Makefile"
else
  echo "未找到 intel-microcode Makefile，跳过修复"
fi

mkdir -p package/base-files/files/etc/uci-defaults

# 第三方软件源（官方 OpenWrt 25.12 推荐）
sed -i '/^src-git \(passwall_packages\|passwall_luci\|istore\|kms\) /d' feeds.conf.default
cat >> feeds.conf.default <<'EOF'
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
src-git kms https://github.com/gaoderby/luci-app-kms.git;main
src-git istore https://github.com/linkease/istore;main
EOF

# Argon 主题
rm -rf package/luci-theme-argon package/luci-app-argon-config
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

# Liquid 主题
git clone https://github.com/xylz0928/luci-theme-liquid.git package/luci-theme-liquid

# OpenClash 插件
rm -rf package/OpenClash
git clone --depth=1 https://github.com/vernesong/OpenClash.git package/OpenClash

# Poweroffdevice 插件
rm -rf package/luci-app-poweroffdevice
git clone --depth=1 https://github.com/sirpdboy/luci-app-poweroffdevice.git package/luci-app-poweroffdevice

# Turboacc 插件
rm -rf package/turboacc
curl -fsSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh -o /tmp/add_turboacc.sh
bash /tmp/add_turboacc.sh
rm -f /tmp/add_turboacc.sh

# 添加 istore
./scripts/feeds update istore
./scripts/feeds install -d y -p istore luci-app-store


echo "=============DIY1 配置完成============"
