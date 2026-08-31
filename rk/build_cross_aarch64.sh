#!/bin/bash
set -e

# 从项目根目录执行
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

TOTAL_STEPS=5
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

step() {
    local n=$1 desc=$2
    local pct=$((n * 100 / TOTAL_STEPS))
    local filled=$((pct / 5))
    local empty=$((20 - filled))
    local bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null) ; seq 1 $empty 2>/dev/null | while read; do printf '░'; done)
    printf "\n${BOLD}${CYAN}[Step %d/%d]${NC} ${GREEN}[%s %3d%%]${NC} %s\n" "$n" "$TOTAL_STEPS" "$bar" "$pct" "$desc"
}

# 清理可能残留的同名容器和旧 sysroot
step 1 "清理旧容器"
sudo docker rm -f temp_container_rk 2>/dev/null || true
sudo docker rm -f cross_container_aarch64 2>/dev/null || true

# 构建 ARM rootfs 基础镜像
step 2 "构建 ARM rootfs 镜像 (base_arm_rootfs_rk)"
sudo docker build --platform linux/arm64 -f rk/Dockerfile -t base_arm_rootfs_rk .

# 导出 rootfs
step 3 "导出 ARM sysroot"
sudo docker create --name temp_container_rk base_arm_rootfs_rk
sudo docker export temp_container_rk -o arm_sysroot.tar
sudo docker rm temp_container_rk

# 构建交叉编译镜像
step 4 "构建交叉编译镜像 (cross-aarch64-rk)"
sudo docker build -f common/Dockerfile.cross -t cross-aarch64-rk .

# arm_sysroot.tar 已打包进镜像，可安全删除
rm -f arm_sysroot.tar

# 运行容器
step 5 "启动编译容器"
printf "\n${BOLD}${GREEN}✅ 构建完成 [100%%]，进入容器...${NC}\n\n"
sudo docker run -it --rm --name cross_container_aarch64 -v ~/workspace:/workspace cross-aarch64-rk bash
