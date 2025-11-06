#!/bin/bash
# 生成 LiBwrt NSS README 文档

REPO_URL="${1}"
PORTING_BRANCH="${2}"
REPO_NAME=$(basename "$REPO_URL" .git)

mkdir -p porting/jdcloud-re-cs-07-libwrt-nss

cat > porting/jdcloud-re-cs-07-libwrt-nss/README.md << EOF
# JDCloud RE-CS-07 固件 (LiBwrt NSS)

## 完整源码分支

完整的 LiBwrt/openwrt-6.x 源码（k6.12-nss）位于本仓库分支：

**分支**: \`${PORTING_BRANCH}\`

[查看源码分支](${REPO_URL}/tree/${PORTING_BRANCH})

## 基于

- **源码**: LiBwrt/openwrt-6.x
- **分支**: k6.12-nss
- **内核**: OpenWrt 6.12
- **NSS**: 完整支持（融合 JiaY-shi + qosmio）

## NSS 硬件加速

- ✅ NSS NAT 硬件加速
- ✅ 2.4G WiFi NSS Offload
- ✅ 5G WiFi NSS Offload
- ✅ ImmortalWrt luci 和 packages
- ✅ OpenWrt 6.12 内核

## 快速编译

\`\`\`bash
# 克隆完整源码
git clone -b ${PORTING_BRANCH} ${REPO_URL}
cd ${REPO_NAME}

# 更新和安装 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 配置
make menuconfig

# 下载依赖
make download -j\$(nproc)

# 编译
make -j\$(nproc) V=s
\`\`\`

## 设备信息

- **厂商**: JDCloud
- **型号**: RE-CS-07
- **SoC**: Qualcomm IPQ6010
- **存储**: eMMC
- **网络**: 4x GbE (3x LAN + 1x WAN)

## 性能优势

| 指标 | 标准版 | LiBwrt NSS |
|------|--------|-----------|
| NAT 转发 | 400-600 Mbps | 900+ Mbps |
| CPU 负载 | 80-90% | 15-25% |
| WiFi 吞吐 | 标准 | NSS 加速 |

## 相关链接

- [源码分支](${REPO_URL}/tree/${PORTING_BRANCH})
- [固件下载](${REPO_URL}/releases)
- [LiBwrt 项目](https://github.com/LiBwrt/openwrt-6.x)
EOF

echo "✅ README 已生成"
