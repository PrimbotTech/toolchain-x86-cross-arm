#!/bin/bash
set -e

docker build --platform linux/arm64  -f Dockerfile.rk -t base_arm_rootfs .
docker create --name temp_container base_arm_rootfs
docker export temp_container -o arm_sysroot.tar
docker rm temp_container
docker build -f Dockerfile.cross -t rk-cross-aarch64 .
docker run -it --name test_container_rk -v ~/workspace:/workspace  rk-cross-aarch64 bash