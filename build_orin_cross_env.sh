#!/bin/bash
set -e

docker build --platform linux/arm64  -f Dockerfile.orin -t base_arm_rootfs_orin .
docker create --name temp_container_orin base_arm_rootfs_orin
docker export temp_container_orin -o arm_sysroot.tar
docker rm temp_container_orin
docker build -f Dockerfile.cross -t orin-cross-aarch64 .
docker run -it --name test_container_orin -v ~/workspace:/workspace  orin-cross-aarch64 bash