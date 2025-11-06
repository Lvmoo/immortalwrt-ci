#!/bin/bash
# 生成 LiBwrt NSS Release 信息

REPO_URL="${1}"
PORTING_BRANCH="${2}"
BUILD_DATE="${3}"

cat > release.txt << EOF
## 📦 OpenWrt JDCloud RE-CS-07 固件 (LiBwrt NSS)

### 🚀 NSS 完整支持

基于 **LiBwrt/openwrt-6.x** (k6.12-nss) 编译

- ✅ NSS NAT 硬件加速
- ✅ 2.4G WiFi NSS Offload
- ✅ 5G WiFi NSS Offload
- ✅ ImmortalWrt luci
- ✅ OpenWrt 6.12 内核

### 📋 编译信息

- **编译时间**: ${BUILD_DATE}
- **源码**: LiBwrt/openwrt-6.x
- **分支**: k6.12-nss
- **平台**: qualcommax/ipq60xx

### 🔗 完整源码

[查看源码分支](${REPO_URL}/tree/${PORTING_BRANCH})

### 📥 固件文件

- \`*-factory.bin\` - 出厂固件
- \`*-sysupgrade.bin\` - 升级固件

### 💡 性能优势

- NAT 转发 900+ Mbps
- CPU 负载降低 70-80%
- WiFi 吞吐量提升
EOF

echo "✅ Release 信息已生成"