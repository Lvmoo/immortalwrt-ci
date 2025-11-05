#!/bin/bash
# 生成 Release 信息

REPO_URL="${1}"
PORTING_BRANCH="${2}"
BUILD_DATE="${3}"

cat > release.txt << 'EOF'
## 📦 OpenWrt JDCloud RE-CS-07 固件

### 📋 编译信息
- 编译时间: BUILD_DATE_PLACEHOLDER
- 源码分支: openwrt-24.10
- 固件平台: qualcommax/ipq60xx
- 设备型号: JDCloud RE-CS-07

### 🔗 完整源码
[immortalwrt-jdcloud-re-cs-07 分支](BRANCH_URL_PLACEHOLDER)

### 📝 关键修复
- ✅ DTS 修复 (`&sdhc` → `&sdhc_1`)
- ✅ 网络配置 (LAN: lan1/lan2/lan3, WAN: wan)
- ✅ eMMC 升级支持
- ✅ 清理冲突包

### ⚠️ 注意事项
- 设备默认不包含无线驱动
- 使用 eMMC 存储，需专用刷写工具
- 网络配置: LAN (lan1/lan2/lan3) + WAN

### 📥 文件说明
- `*-factory.bin`: 出厂固件（首次刷写）
- `*-sysupgrade.bin`: 升级固件（系统升级）
- `jdcloud-re-cs-07-port.patch`: 移植补丁

### 🛠️ 快速编译

```bash
git clone -b PORTING_BRANCH_PLACEHOLDER CLONE_URL_PLACEHOLDER
cd REPO_DIR_PLACEHOLDER
./scripts/feeds update -a && ./scripts/feeds install -a
make menuconfig && make -j$(nproc)
```
EOF

# 替换占位符
sed -i "s|BUILD_DATE_PLACEHOLDER|${BUILD_DATE}|g" release.txt
sed -i "s|BRANCH_URL_PLACEHOLDER|${REPO_URL}/tree/${PORTING_BRANCH}|g" release.txt
sed -i "s|CLONE_URL_PLACEHOLDER|${REPO_URL}.git|g" release.txt
sed -i "s|PORTING_BRANCH_PLACEHOLDER|${PORTING_BRANCH}|g" release.txt
sed -i "s|REPO_DIR_PLACEHOLDER|$(basename ${REPO_URL})|g" release.txt

echo "✅ release.txt 已生成"
