#!/bin/bash
# JDCloud RE-CS-07 设备移植脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
log_step() { echo -e "${BLUE}[====]${NC} $1"; }

WORK_DIR="$(pwd)"
VIKINGYFY_DIR="../vikingyfy-immortalwrt"
BRANCH_NAME="jdcloud-re-cs-07"

# 创建移植分支
create_branch() {
    log_step "创建/切换移植分支..."
    
    # 确保在 git 仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "当前目录不是 git 仓库"
    fi
    
    # 检查是否有未提交的更改
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log_warn "检测到未提交的更改，将保存到 stash"
        git stash push -m "Auto stash before branch switch"
    fi
    
    # 检查分支是否存在
    if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
        log_warn "分支 '$BRANCH_NAME' 已存在，切换到该分支"
        git checkout "$BRANCH_NAME"
        
        # 如果有 stash，尝试恢复
        if git stash list | grep -q "Auto stash before branch switch"; then
            log_info "恢复之前保存的更改..."
            git stash pop || log_warn "无法自动恢复更改，请手动处理"
        fi
    else
        log_info "创建新分支: $BRANCH_NAME"
        git checkout -b "$BRANCH_NAME"
    fi
    
    log_info "当前分支: $(git branch --show-current)"
}

# 移植 DTS 文件
port_dts() {
    log_step "移植设备树文件..."
    
    local DTS_DIR="target/linux/qualcommax/files/arch/arm64/boot/dts/qcom"
    mkdir -p "$DTS_DIR"
    
    # 复制主 DTS 文件
    log_info "复制 ipq6010-re-cs-07.dts"
    cp "$VIKINGYFY_DIR/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6010-re-cs-07.dts" \
       "$DTS_DIR/" || log_error "DTS 文件复制失败"
    
    # 修复 sdhc 引用 - 将 &sdhc 改为 &sdhc_1
    log_info "修复 DTS 文件中的 sdhc 引用..."
    sed -i 's/&sdhc {/\&sdhc_1 {/g' "$DTS_DIR/ipq6010-re-cs-07.dts"
    
    # 验证修改
    if grep -q "&sdhc_1" "$DTS_DIR/ipq6010-re-cs-07.dts"; then
        log_info "  ✓ sdhc 引用已修复为 sdhc_1"
    else
        log_warn "  ! 未找到 sdhc_1 引用，可能不需要修改"
    fi
    
    # 复制 DTSI 依赖文件
    log_info "复制依赖的 dtsi 文件"
    for dtsi in ipq6018-ess.dtsi ipq6018-nss.dtsi ipq6018-common.dtsi; do
        if [ -f "$VIKINGYFY_DIR/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/$dtsi" ]; then
            cp "$VIKINGYFY_DIR/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/$dtsi" \
               "$DTS_DIR/"
            log_info "  ✓ $dtsi"
        else
            log_warn "  ! $dtsi 不存在（可能在内核中）"
        fi
    done
    
    log_info "DTS 文件移植完成"
}

# 添加设备配置到 Image Makefile
port_image_config() {
    log_step "添加设备配置..."
    
    local IMAGE_MK="target/linux/qualcommax/image/ipq60xx.mk"
    
    [ ! -f "$IMAGE_MK" ] && log_error "未找到 $IMAGE_MK"
    
    # 检查是否已添加
    if grep -q "jdcloud_re-cs-07" "$IMAGE_MK"; then
        log_warn "设备配置已存在，跳过添加"
        return 0
    fi
    
    log_info "添加 JDCloud RE-CS-07 到 Image Makefile"
    
    cat >> "$IMAGE_MK" << 'DEVICE_EOF'

define Device/jdcloud_re-cs-07
	$(call Device/FitImage)
	$(call Device/EmmcImage)
	DEVICE_VENDOR := JDCloud
	DEVICE_MODEL := RE-CS-07
	KERNEL_SIZE := 6144k
	BLOCKSIZE := 128k
	SOC := ipq6010
	DEVICE_DTS_CONFIG := config@cp03-c4
	DEVICE_PACKAGES := -ath11k-firmware-ipq6018 -ath11k-firmware-qcn9074 -kmod-ath11k -kmod-ath11k-ahb -kmod-ath11k-pci -hostapd-common -wpad-openssl
	IMAGE/factory.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-rootfs | append-metadata
endef
TARGET_DEVICES += jdcloud_re-cs-07
DEVICE_EOF
    
    log_info "设备配置已添加"
}

# 移植 base-files
port_base_files() {
    log_step "移植 base-files 配置..."
    
    local BASE_DIR="target/linux/qualcommax/ipq60xx/base-files"
    
    # 1. 网络配置
    log_info "配置网络接口..."
    local NETWORK_FILE="$BASE_DIR/etc/board.d/02_network"
    
    [ ! -f "$NETWORK_FILE" ] && log_error "网络配置文件不存在: $NETWORK_FILE"
    
    if ! grep -q "jdcloud,re-cs-07" "$NETWORK_FILE"; then
        # 查找合适的插入位置 - 在 ipq60xx_setup_interfaces() 函数内的 case 语句中
        if grep -q "ipq60xx_setup_interfaces()" "$NETWORK_FILE"; then
            # 在最后一个设备配置之后、esac 之前插入
            sed -i '/ipq60xx_setup_interfaces()/,/^}$/ {
                /^[[:space:]]*esac[[:space:]]*$/i\
	jdcloud,re-cs-07)\
		ucidef_set_interfaces_lan_wan "lan1 lan2 lan3" "wan"\
		;;
            }' "$NETWORK_FILE"
            log_info "  ✓ 网络配置已添加"
        else
            log_error "  ✗ 未找到 ipq60xx_setup_interfaces() 函数"
        fi
    else
        log_warn "  ! 网络配置已存在"
    fi
    
    # 2. 升级脚本
    log_info "配置升级脚本..."
    local UPGRADE_FILE="$BASE_DIR/lib/upgrade/platform.sh"
    
    [ ! -f "$UPGRADE_FILE" ] && log_error "升级脚本不存在: $UPGRADE_FILE"
    
    # 添加到 platform_do_upgrade
    if ! grep -q "jdcloud,re-cs-07" "$UPGRADE_FILE"; then
        # 在 platform_do_upgrade 函数的 case 语句中插入
        sed -i '/platform_do_upgrade()/,/^}$/ {
            /^[[:space:]]*case.*board_name.*$/a\
	jdcloud,re-cs-07)\
		CI_KERNPART="0:HLOS"\
		CI_ROOTPART="rootfs"\
		emmc_do_upgrade "$1"\
		;;
        }' "$UPGRADE_FILE"
        log_info "  ✓ platform_do_upgrade 已添加"
    else
        log_warn "  ! platform_do_upgrade 已存在"
    fi
    
    # 添加 platform_copy_config 函数
    if ! grep -q "platform_copy_config()" "$UPGRADE_FILE"; then
        cat >> "$UPGRADE_FILE" << 'COPY_CONFIG_EOF'

platform_copy_config() {
	case "$(board_name)" in
	jdcloud,re-cs-07)
		emmc_copy_config
		;;
	esac
}
COPY_CONFIG_EOF
        log_info "  ✓ platform_copy_config 已添加"
    else
        if ! grep "platform_copy_config" -A 10 "$UPGRADE_FILE" | grep -q "jdcloud,re-cs-07"; then
            sed -i '/platform_copy_config()/,/^}$/ {
                /^[[:space:]]*case.*board_name.*$/a\
	jdcloud,re-cs-07)\
		emmc_copy_config\
		;;
            }' "$UPGRADE_FILE"
            log_info "  ✓ platform_copy_config 配置已添加"
        else
            log_warn "  ! platform_copy_config 已配置"
        fi
    fi
    
    log_info "base-files 移植完成"
}

# 应用额外补丁
apply_extra_patches() {
    log_step "应用额外补丁..."
    
    # 移除 luci-app-cpufreq（如果存在）
    local MAKEFILE="target/linux/qualcommax/Makefile"
    if [ -f "$MAKEFILE" ] && grep -q "luci-app-cpufreq" "$MAKEFILE"; then
        log_info "从 Makefile 中移除 luci-app-cpufreq"
        sed -i 's/luci-app-cpufreq//g' "$MAKEFILE"
    fi
    
    log_info "额外补丁应用完成"
}

# 提交更改
commit_changes() {
    log_step "提交移植更改..."
    
    # 检查是否有更改
    if git diff --quiet && git diff --cached --quiet; then
        log_warn "没有检测到更改，跳过提交"
        return 0
    fi
    
    # 添加所有更改
    git add -A
    
    # 显示更改统计
    log_info "更改统计:"
    git diff --cached --stat | sed 's/^/  /'
    
    # 提交更改
    local commit_msg="Add JDCloud RE-CS-07 device support

- Add device tree files (ipq6010-re-cs-07.dts and dependencies)
- Fix sdhc reference to sdhc_1 in DTS
- Add device configuration to ipq60xx.mk
- Add network configuration (lan1/lan2/lan3 + wan)
- Add upgrade scripts for eMMC support
- Remove luci-app-cpufreq from qualcommax Makefile

Generated by automated porting script"
    
    git commit -m "$commit_msg"
    
    log_info "更改已提交到分支: $BRANCH_NAME"
    log_info "提交哈希: $(git rev-parse --short HEAD)"
}

# 生成补丁文件
generate_patch() {
    log_step "生成补丁文件..."
    
    local PATCH_DIR="../patches"
    local PATCH_FILE="$PATCH_DIR/jdcloud-re-cs-07-port.patch"
    
    # 创建补丁目录
    mkdir -p "$PATCH_DIR"
    
    # 获取基础分支
    local base_branch=$(git branch -r | grep -E 'origin/(openwrt-24.10|master|main)' | head -1 | sed 's/.*origin\///')
    
    if [ -z "$base_branch" ]; then
        log_warn "未找到基础分支，使用当前提交的父提交作为基础"
        git diff HEAD~1 > "$PATCH_FILE"
    else
        base_branch="origin/$base_branch"
        log_info "基础分支: $base_branch"
        git diff "$base_branch".."$BRANCH_NAME" > "$PATCH_FILE"
    fi
    
    if [ -s "$PATCH_FILE" ]; then
        log_info "✅ 补丁文件已生成: $PATCH_FILE"
        log_info "补丁大小: $(du -h "$PATCH_FILE" | cut -f1)"
        log_info "应用补丁命令: git apply $PATCH_FILE"
    else
        log_warn "补丁文件为空，可能没有更改"
        rm -f "$PATCH_FILE"
    fi
}

# 验证移植
verify_port() {
    log_step "验证移植..."
    
    local errors=0
    
    # 检查 DTS
    if [ -f "target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6010-re-cs-07.dts" ]; then
        log_info "  ✓ DTS 文件存在"
        
        # 验证 sdhc_1 引用
        if grep -q "&sdhc_1" "target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6010-re-cs-07.dts"; then
            log_info "  ✓ DTS 使用正确的 sdhc_1 引用"
        else
            log_warn "  ! DTS 未使用 sdhc_1 引用"
        fi
    else
        log_error "  ✗ DTS 文件缺失"
        errors=$((errors + 1))
    fi
    
    # 检查 Image config
    if grep -q "TARGET_DEVICES += jdcloud_re-cs-07" "target/linux/qualcommax/image/ipq60xx.mk"; then
        log_info "  ✓ Image 配置存在"
    else
        log_error "  ✗ Image 配置缺失"
        errors=$((errors + 1))
    fi
    
    # 检查网络配置
    local NETWORK_FILE="target/linux/qualcommax/ipq60xx/base-files/etc/board.d/02_network"
    if [ -f "$NETWORK_FILE" ] && grep -q "jdcloud,re-cs-07" "$NETWORK_FILE"; then
        log_info "  ✓ 网络配置存在"
    else
        log_warn "  ! 网络配置缺失"
        errors=$((errors + 1))
    fi
    
    # 检查升级脚本
    local UPGRADE_FILE="target/linux/qualcommax/ipq60xx/base-files/lib/upgrade/platform.sh"
    if [ -f "$UPGRADE_FILE" ] && grep -q "jdcloud,re-cs-07" "$UPGRADE_FILE"; then
        log_info "  ✓ platform_do_upgrade 配置存在"
    else
        log_warn "  ! platform_do_upgrade 配置缺失"
        errors=$((errors + 1))
    fi
    
    # 检查分支
    local current_branch=$(git branch --show-current)
    if [ "$current_branch" = "$BRANCH_NAME" ]; then
        log_info "  ✓ 位于正确的分支: $BRANCH_NAME"
    else
        log_warn "  ! 当前分支: $current_branch (预期: $BRANCH_NAME)"
    fi
    
    if [ $errors -eq 0 ]; then
        log_info "✅ 移植验证通过！"
        return 0
    else
        log_warn "⚠️ 发现 $errors 个问题，但继续执行"
        return 0
    fi
}

# 显示移植摘要
show_summary() {
    log_step "移植摘要"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  JDCloud RE-CS-07 移植完成"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📌 分支信息:"
    echo "  当前分支: $(git branch --show-current)"
    echo "  最新提交: $(git log -1 --oneline)"
    echo ""
    echo "📦 移植内容:"
    echo "  ✓ DTS 设备树文件 (包含 sdhc_1 修复)"
    echo "  ✓ Image 配置 (ipq60xx.mk)"
    echo "  ✓ 网络配置 (lan1/lan2/lan3 + wan)"
    echo "  ✓ 升级脚本 (eMMC support)"
    echo "  ✓ Makefile 修复 (移除 cpufreq)"
    echo ""
    
    # 检查补丁文件
    if [ -f "../patches/jdcloud-re-cs-07-port.patch" ]; then
        echo "📄 补丁文件:"
        echo "  ../patches/jdcloud-re-cs-07-port.patch"
        echo ""
    fi
    
    echo "⚠️  注意事项:"
    echo "  • 设备默认不包含无线驱动"
    echo "  • 使用 eMMC 存储"
    echo "  • 需要专用刷写工具"
    echo ""
}

# 完整移植流程
port_all() {
    log_step "开始完整移植流程..."
    
    create_branch
    port_dts
    port_image_config
    port_base_files
    apply_extra_patches
    verify_port
    commit_changes
    generate_patch
    show_summary
    
    log_info "🎉 移植完成！"
}

# 主函数
main() {
    local action=$1
    
    case $action in
        port)
            port_all
            ;;
        branch)
            create_branch
            ;;
        dts)
            port_dts
            ;;
        image)
            port_image_config
            ;;
        base)
            port_base_files
            ;;
        patch)
            apply_extra_patches
            ;;
        commit)
            commit_changes
            ;;
        generate_patch)
            generate_patch
            ;;
        verify)
            verify_port
            ;;
        summary)
            show_summary
            ;;
        *)
            log_error "未知操作: $action
使用方法:
  $0 port           - 完整移植（推荐）
  $0 branch         - 创建/切换分支
  $0 dts            - 仅移植 DTS
  $0 image          - 仅移植 Image 配置
  $0 base           - 仅移植 base-files
  $0 patch          - 应用额外补丁
  $0 commit         - 提交更改
  $0 generate_patch - 生成补丁文件
  $0 verify         - 验证移植
  $0 summary        - 显示摘要"
            ;;
    esac
}

# 如果直接执行脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
