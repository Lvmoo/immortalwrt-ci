#!/bin/bash
# 通用 CI 脚本 - 处理依赖、feeds 等通用操作

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 安装编译依赖
install_deps() {
    log_info "更新软件源..."
    sudo apt-get update -y
    
    log_info "安装编译依赖..."
    sudo apt-get install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
      bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib \
      g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
      libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
      libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano \
      ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils \
      python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs \
      upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd
    
    log_info "依赖安装完成"
}

# 克隆源码
clone_source() {
    local repo_url=$1
    local repo_branch=${2:-openwrt-24.10}
    
    log_info "克隆 ImmortalWrt 源码..."
    log_info "仓库: $repo_url"
    log_info "分支: $repo_branch"
    
    if [ -d "immortalwrt" ]; then
        log_warn "immortalwrt 目录已存在，删除旧目录"
        rm -rf immortalwrt
    fi
    
    #git clone --depth=1 -b "$repo_branch" "$repo_url" immortalwrt
    git clone -b "$repo_branch" "$repo_url" immortalwrt
    
    log_info "源码克隆完成"
}

# 更新和安装 feeds
update_feeds() {
    log_info "更新 feeds..."
    ./scripts/feeds update -a
    
    log_info "安装 feeds..."
    ./scripts/feeds install -a
    
    log_info "Feeds 配置完成"
}

# 清理构建环境
clean_build() {
    local clean_type=${1:-all}
    
    case $clean_type in
        dl)
            log_info "清理下载目录..."
            rm -rf dl
            ;;
        bin)
            log_info "清理输出目录..."
            rm -rf bin
            ;;
        all)
            log_info "完全清理..."
            make clean
            rm -rf bin tmp logs
            ;;
        distclean)
            log_info "彻底清理（包括工具链）..."
            make distclean
            ;;
        *)
            log_error "未知的清理类型: $clean_type"
            ;;
    esac
    
    log_info "清理完成"
}

# 显示系统信息
show_system_info() {
    log_info "系统信息:"
    echo "  CPU: $(nproc) 核"
    echo "  内存: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "  磁盘: $(df -h . | awk 'NR==2 {print $4}') 可用"
    echo "  系统: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
}

# 主函数
main() {
    local action=$1
    shift
    
    case $action in
        install_deps)
            install_deps
            ;;
        clone_source)
            clone_source "$@"
            ;;
        update_feeds)
            update_feeds
            ;;
        clean)
            clean_build "$@"
            ;;
        info)
            show_system_info
            ;;
        *)
            log_error "未知操作: $action
使用方法:
  $0 install_deps              - 安装编译依赖
  $0 clone_source <url> [branch] - 克隆源码
  $0 update_feeds              - 更新和安装 feeds
  $0 clean [all|dl|bin|distclean] - 清理构建
  $0 info                      - 显示系统信息"
            ;;
    esac
}

# 如果直接执行脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
