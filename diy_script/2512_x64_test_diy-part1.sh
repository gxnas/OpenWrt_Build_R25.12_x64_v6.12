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

# AdGuardHome 插件
rm -rf package/luci-app-adguardhome
git clone --depth=1 https://github.com/kongfl888/luci-app-adguardhome package/luci-app-adguardhome
# ==================== 预置 AdGuardHome 核心（自动最新版） ====================
echo "正在添加 AdGuardHome 核心包（自动获取最新版本）..."

rm -rf package/adguardhome-core
mkdir -p package/adguardhome-core

# 获取最新版本号
LATEST_VER=$(curl -sL https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | \
             grep -oP '"tag_name": "\K[^"]+' | head -1 | sed 's/^v//')

if [ -z "$LATEST_VER" ]; then
    echo "警告：获取 AdGuardHome 最新版本失败，使用默认版本 0.107.80"
    LATEST_VER="0.107.80"
fi

echo "AdGuardHome 最新版本: v${LATEST_VER}"

# 生成 Makefile
cat > package/adguardhome-core/Makefile << EOF
include \$(TOPDIR)/rules.mk

PKG_NAME:=adguardhome-core
PKG_VERSION:=${LATEST_VER}
PKG_RELEASE:=1

PKG_SOURCE:=AdGuardHome_linux_amd64.tar.gz
PKG_SOURCE_URL:=https://github.com/AdguardTeam/AdGuardHome/releases/download/v\$(PKG_VERSION)/
PKG_HASH:=skip

PKG_LICENSE:=GPL-3.0-only

include \$(INCLUDE_DIR)/package.mk

define Package/adguardhome-core
  SECTION:=net
  CATEGORY:=Network
  TITLE:=AdGuard Home Core (prebuilt binary for x86_64)
  URL:=https://github.com/AdguardTeam/AdGuardHome
endef

define Package/adguardhome-core/description
  Prebuilt AdGuard Home binary. Installed to /usr/bin/AdGuardHome
endef

define Build/Prepare
	mkdir -p \$(PKG_BUILD_DIR)
	tar -zxf \$(DL_DIR)/\$(PKG_SOURCE) -C \$(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/adguardhome-core/install
	\$(INSTALL_DIR) \$(1)/usr/bin
	\$(INSTALL_BIN) \$(PKG_BUILD_DIR)/AdGuardHome/AdGuardHome \$(1)/usr/bin/AdGuardHome
endef

\$(eval \$(call BuildPackage,adguardhome-core))
EOF

echo "adguardhome-core 包已生成（版本 v${LATEST_VER}）"
# ===========================================================================

# Argon 主题
rm -rf package/luci-theme-argon package/luci-app-argon-config
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

# Liquid 主题
git clone https://github.com/xylz0928/luci-theme-liquid.git package/luci-theme-liquid

# Lucky 插件
rm -rf package/lucky
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/lucky

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
