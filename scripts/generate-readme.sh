#!/bin/bash
# 生成移植 README 文档

REPO_URL="${1:-https://github.com/YOUR_USERNAME/YOUR_REPO}"
PORTING_BRANCH="${2:-immortalwrt-jdcloud-re-cs-07}"

cat > porting/jdcloud-re-cs-07/README.md << 'EOF'
# JDCloud RE-CS-07 移植文档

## 完整源码分支

移植后的完整 ImmortalWrt 源码位于本仓库的独立分支 `PORTING_BRANCH_PLACEHOLDER`

## 方法 1: 直接使用移植分支（推荐）

克隆移植分支（完整源码）：

\`\`\`bash
git clone -b PORTING_BRANCH_PLACEHOLDER REPO_URL_PLACEHOLDER
cd REPO_NAME_PLACEHOLDER
./scripts/feeds update -a
./scripts/feeds install -a
make menuconfig
make download -j$(nproc)
make -j$(nproc) || make -j1 V=s
\`\`\`

## 方法 2: 应用补丁到官方源码

\`\`\`bash
git clone -b openwrt-24.10 https://github.com/immortalwrt/immortalwrt
cd immortalwrt
wget REPO_URL_PLACEHOLDER/raw/main/porting/jdcloud-re-cs-07/jdcloud-re-cs-07-port.patch
git apply jdcloud-re-cs-07-port.patch
./scripts/feeds update -a
./scripts/feeds install -a
make menuconfig
\`\`\`

## 设备信息

- **厂商**: JDCloud
- **型号**: RE-CS-07
- **SoC**: Qualcomm IPQ6010
- **存储**: eMMC
- **网络**: 4x GbE (3x LAN + 1x WAN)

## 关键修改

1. DTS 修复: \`&sdhc\` → \`&sdhc_1\`
2. 网络配置: LAN (lan1/lan2/lan3) + WAN
3. eMMC 升级支持
4. 清理冲突包

## 相关链接

- [完整源码分支](../../tree/PORTING_BRANCH_PLACEHOLDER)
- [补丁文件](jdcloud-re-cs-07-port.patch)
- [配置文件](../../blob/main/configs/jdcloud-re-cs-07.config)
- [固件下载](../../releases)
EOF

# 替换占位符
sed -i "s|REPO_URL_PLACEHOLDER|${REPO_URL}|g" porting/jdcloud-re-cs-07/README.md
sed -i "s|PORTING_BRANCH_PLACEHOLDER|${PORTING_BRANCH}|g" porting/jdcloud-re-cs-07/README.md
sed -i "s|REPO_NAME_PLACEHOLDER|$(basename ${REPO_URL} .git)|g" porting/jdcloud-re-cs-07/README.md

echo "✅ README.md 已生成"
