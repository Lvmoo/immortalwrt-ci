#!/bin/bash
# OpenWrt 构建脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 构建固件
build_firmware() {
    local build_mode=${1:-multi}
    local verbose=${2:-}
    
    log_step "开始构建固件..."
    
    # 显示配置信息
    log_info "构建配置:"
    echo "  Target: $(grep '^CONFIG_TARGET_BOARD=' .config | cut -d'=' -f2 | tr -d '"')"
    echo "  Subtarget: $(grep '^CONFIG_TARGET_SUBTARGET=' .config | cut -d'=' -f2 | tr -d '"')"
    
    # 显示磁盘空间
    log_info "开始前磁盘空间:"
    df -h . | tail -1
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    case $build_mode in
        single)
            log_info "使用单线程编译（便于调试）..."
            if [ -n "$verbose" ]; then
                make -j1 V=s
            else
                make -j1
            fi
            ;;
        multi)
            log_info "使用多线程编译..."
            make -j$(nproc) || {
                log_warn "多线程编译失败，尝试单线程编译..."
                make -j1 V=s
            }
            ;;
        *)
            log_error "未知的构建模式: $build_mode"
            ;;
    esac
    
    # 计算编译时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    log_info "✅ 编译完成！"
    log_info "编译用时: ${minutes} 分 ${seconds} 秒"
    
    # 显示磁盘空间
    log_info "编译后磁盘空间:"
    df -h . | tail -1
    
    # 显示生成的文件
    show_build_results
}

# 显示构建结果
show_build_results() {
    log_info "生成的固件文件:"
    
    if [ -d "bin/targets" ]; then
        find bin/targets -type f \( -name "*.bin" -o -name "*.img.gz" -o -name "*.vmdk" \) -exec ls -lh {} \; | awk '{print "  " $9 " (" $5 ")"}'
    else
        log_warn "未找到输出文件"
    fi
}

# 验证构建
verify_build() {
    log_step "验证构建结果..."
    
    local errors=0
    
    if [ ! -d "bin/targets" ]; then
        log_error "构建失败：未找到 bin/targets 目录"
        errors=$((errors + 1))
    fi
    
    local firmware_count=$(find bin/targets -type f \( -name "*.bin" -o -name "*.img.gz" \) | wc -l)
    if [ $firmware_count -eq 0 ]; then
        log_warn "警告：未找到固件文件"
        errors=$((errors + 1))
    else
        log_info "找到 $firmware_count 个固件文件"
    fi
    
    if [ $errors -eq 0 ]; then
        log_info "✅ 构建验证通过"
        return 0
    else
        log_error "❌ 构建验证失败"
        return 1
    fi
}

# 主函数
main() {
    local action=$1
    shift
    
    case $action in
        build)
            build_firmware "$@"
            ;;
        verify)
            verify_build
            ;;
        show)
            show_build_results
            ;;
        *)
            log_error "未知操作: $action
使用方法:
  $0 build [single|multi] [verbose] - 构建固件
  $0 verify                         - 验证构建结果
  $0 show                           - 显示构建结果"
            ;;
    esac
}

# 如果直接执行脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
