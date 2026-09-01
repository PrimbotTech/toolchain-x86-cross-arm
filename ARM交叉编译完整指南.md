# ARM 交叉编译完整指南

本文档介绍如何在 x86 主机上使用 Docker 容器进行 ARM (aarch64) 交叉编译，适用于 RK 和 Orin 两种目标平台。

## 目录

- [前置要求](#前置要求)
  - [硬件架构](#硬件架构)
  - [软件要求](#软件要求)
  - [存储与网络](#存储与网络)
- [1. 准备交叉编译环境](#1-准备交叉编译环境)
  - [方式一：导入现成镜像（推荐）](#方式一导入现成镜像推荐)
  - [方式二：从零自行构建](#方式二从零自行构建)
  - [镜像导出与分发](#镜像导出与分发)
- [2. 进入容器并编译代码](#2-进入容器并编译代码)
  - [2.1 工作目录准备](#21-工作目录准备)
  - [2.2 启动容器](#22-启动容器)
  - [2.3 编译项目](#23-编译项目)
  - [2.4 集成自己的代码](#24-集成自己的代码)
    - [C++ 项目（ROS 2 / colcon）](#c-项目ros-2--colcon)
    - [Python 项目](#python-项目)
    - [混合项目（C++ + Python 绑定）](#混合项目c--python-绑定)
  - [2.5 常见编译选项](#25-常见编译选项)
- [3. 产物导出与部署](#3-产物导出与部署)
  - [3.1 编译产物结构](#31-编译产物结构)
  - [3.2 导出产物到目标板](#32-导出产物到目标板)
    - [部署前必须：修复路径](#部署前必须修复路径)
    - [方式一：直接拷贝 install 目录](#方式一直接拷贝-install-目录)
    - [方式二：推荐的完整部署结构](#方式二推荐的完整部署结构)
  - [3.3 在目标板上运行](#33-在目标板上运行)
    - [方式一：直接执行二进制（推荐）](#方式一直接执行二进制推荐)
    - [方式二：使用 ros2 run](#方式二使用-ros2-run需要目标板安装了-ros2-cli-工具)
  - [3.4 运行前检查清单](#34-运行前检查清单)
  - [3.5 Windows 换行符问题](#35-windows-换行符问题)
- [附录：平台差异速查](#附录平台差异速查)

---

## 前置要求

在开始之前，请确认宿主机满足以下条件：

### 硬件架构

宿主机 CPU 必须是 **x86_64 架构**（Intel 或 AMD 处理器）。

> **Apple M 系列芯片（M1/M2/M3 等）用户注意：** M 系 Mac 本身是 ARM 架构，理论上可以直接使用 `docker_arm_native_arm` 项目在本地原生编译 ARM 代码，无需交叉编译。本工程的 `Dockerfile.cross` 强制拉取 x86 版 Ubuntu 22.04 并安装 `gcc-aarch64-linux-gnu` 工具链，M 系 Mac 需要通过 Rosetta 模拟运行 x86 Docker 容器去编译 ARM 代码，性能大打折扣且容易出现难以排查的问题。建议 M 系用户优先考虑 `docker_arm_native_arm` 原生 ARM 编译方案。

### 软件要求

- **Docker**：安装较新版本的 Docker Engine（Linux）或 Docker Desktop（Mac/Windows）。确保 Docker 配置了足够的共享挂载权限，尤其是 Windows / Mac 用户需要将 `~/workspace` 所在目录加入 Docker 的文件共享列表。
- **QEMU 多架构支持**：构建脚本中使用了 `docker build --platform linux/arm64`，Docker 需要在 x86 主机上模拟 ARM 架构来构建 RootFS 镜像。
  - **Ubuntu 宿主机**：必须手动安装 QEMU 支持：
    ```bash
    sudo apt-get install qemu binfmt-support qemu-user-static
    ```
    未安装时执行构建脚本会直接报错。
  - **Mac / Windows（Docker Desktop）**：无需额外操作，Docker Desktop 已内置跨平台模拟功能。

### 存储与网络

- **磁盘空间**：两个平台的镜像体积差异很大，请根据实际使用的平台预留空间：

| 平台 | 本地占用（docker images） | 传输大小（gzip 压缩后） | 说明 |
|------|--------------------------|------------------------|------|
| RK | ~5.4 GB | ~1.3 GB | 不含 CUDA，体积较小 |
| Orin | ~44.6 GB | ~15.7 GB | 含 CUDA 12.6 / cuDNN 9 / TensorRT，体积很大 |

  - **本地占用**（`docker images` SIZE 列）：镜像在磁盘上以**解压状态**存储，Docker 为了容器快速运行不会对层做压缩，所以这个数字是实际占用的磁盘空间。
  - **传输大小**（`docker save` 后 gzip 压缩的 `.tar.gz`）：gzip 对库文件、二进制等系统文件通常有 3–4 倍压缩率，所以传输文件比本地占用小很多。同事拿到文件后执行 `docker load` 会解压还原，最终占用仍然等于本地占用大小。

  简单来说：**本地占用是跑起来要占多少盘，传输大小是发给别人要传多少数据**。

  构建过程中还会产生临时的 rootfs tar 包（数 GB），加上中间镜像层的叠加，实际构建期间的磁盘占用会大于最终镜像大小。建议预留空间：
  - **仅构建 RK**：至少 **15 GB**
  - **构建 Orin**：至少 **60 GB**（基础镜像 + 中间层 + 最终镜像叠加）

- **网络**：需能访问公网 Docker Hub、清华镜像源（Tuna）以及 NVIDIA 官方源。Orin 构建时需额外拉取 NVIDIA L4T 基础镜像（约 2 GB），下载时间更长。

---

## 1. 准备交叉编译环境

交叉编译环境是一个运行在 x86 主机上的 Docker 容器，内含 aarch64 工具链、目标平台的 sysroot（系统库和头文件）以及所有必要的依赖。

你有两种方式获取该环境：**导入现成镜像**（推荐，快速）或 **从零自行构建**。

### 方式一：导入现成镜像（推荐）

如果已经有人构建好了镜像并导出为 `.tar.gz` 文件，直接导入即可：

```bash
# RK 平台
gunzip -c cross-aarch64-rk.tar.gz | sudo docker load

# Orin 平台
gunzip -c cross-aarch64-orin.tar.gz | sudo docker load
```

导入完成后，可用 `docker images` 确认镜像已就绪：

```bash
sudo docker images | grep cross-aarch64
# 应看到 cross-aarch64-rk 或 cross-aarch64-orin
```

### 方式二：从零自行构建

如果需要修改依赖或重建环境，在本项目根目录下执行对应平台的构建脚本：

```bash
# RK 平台（基于 ros:humble-ros-base，不含 CUDA）
chmod +x rk/build_cross_aarch64.sh && ./rk/build_cross_aarch64.sh

# Orin 平台（基于 l4t-base:r36.2.0，含 CUDA / cuDNN / TensorRT）
chmod +x orin/build_cross_aarch64.sh && ./orin/build_cross_aarch64.sh
```

> 构建脚本内部调用了 `docker build`、`docker create`、`docker export`、`docker run` 等命令，需要 sudo 权限。如果当前用户未加入 docker 组，请在脚本内为 docker 命令加上 `sudo`，或先执行 `sudo usermod -aG docker $USER` 后重新登录。

构建过程分为两步：
1. **构建目标板 rootfs 镜像** — 以 `linux/arm64` 模式运行平台专属 Dockerfile，安装 ROS 2、OpenCV、ONNX Runtime 等全部依赖
2. **导出 sysroot 并构建交叉编译容器** — 将 rootfs 导出为 tar，再由 `common/Dockerfile.cross` 打包成包含 aarch64 工具链的 x86 交叉编译镜像

> **构建耗时较长。** 由于 x86 主机需要通过 QEMU 模拟 ARM 架构来执行 `apt-get install`、`pip install` 等操作，速度比原生慢 5–10 倍。RK 镜像大约需要 **1–2 小时**，Orin 镜像（依赖更多、体积更大）可能需要 **3–5 小时**，具体取决于网络速度和宿主机性能。构建完成后会自动进入容器 bash，输入 `exit` 退出即可。

### 镜像导出与分发

构建好的镜像可导出为压缩文件，方便分发给团队其他成员：

```bash
# 导出 RK 镜像
sudo docker save cross-aarch64-rk | gzip > cross-aarch64-rk.tar.gz

# 导出 Orin 镜像
sudo docker save cross-aarch64-orin | gzip > cross-aarch64-orin.tar.gz
```

---

## 2. 进入容器并编译代码

### 2.1 工作目录准备

在宿主机上准备一个工作目录，将需要编译的代码放入其中：

```bash
# 在宿主机 home 目录下创建 workspace
mkdir -p ~/workspace

# 将项目代码放入 workspace
cp -r /path/to/sdk_q1 ~/workspace/
cp -r /path/to/sdk_t1 ~/workspace/
```

> `~/workspace` 会挂载到容器内的 `/workspace`，编译结果直接保留在宿主机上，容器退出后不会丢失。

### 2.2 启动容器

```bash
# RK 平台
sudo docker run -it --rm --net=host -v ~/workspace:/workspace -w /workspace cross-aarch64-rk bash

# Orin 平台
sudo docker run -it --rm --net=host -v ~/workspace:/workspace -w /workspace cross-aarch64-orin bash
```

参数说明：
| 参数 | 作用 |
|------|------|
| `-it` | 交互式终端 |
| `--rm` | 退出后自动删除容器（数据在 workspace 中已持久化） |
| `--net=host` | 共享宿主机网络（编译过程中可能需要下载依赖） |
| `-v ~/workspace:/workspace` | 挂载宿主机工作目录 |
| `-w /workspace` | 设置容器内默认工作目录 |

### 2.3 编译项目

容器内已预配置好 CMake 工具链文件（`CMAKE_TOOLCHAIN_FILE`），直接编译即可：

```bash
cd sdk_q1
colcon build

cd ../sdk_t1
colcon build
```

### 2.4 集成自己的代码

将你自己的项目代码放入 `~/workspace` 目录下，容器内即可访问和编译。以下是 C++ 和 Python 项目的集成方式。

#### C++ 项目（ROS 2 / colcon）

将你的 ROS 2 包放入 workspace：

```
~/workspace/
├── sdk_q1/
├── sdk_t1/
└── my_cpp_pkg/          # 你的 C++ 包
    ├── CMakeLists.txt
    ├── package.xml
    ├── include/
    │   └── my_cpp_pkg/
    │       └── my_node.hpp
    └── src/
        └── my_node.cpp
```

在容器内编译：

```bash
cd /workspace/my_cpp_pkg
colcon build
# 或回到 workspace 根目录一次性编译所有包：
cd /workspace
colcon build --packages-select my_cpp_pkg
```

> 交叉编译环境已预置 aarch64 工具链和 sysroot，`find_package` 会自动在 sysroot 内搜索 ROS 2、OpenCV、Python 等依赖，无需额外配置。

#### Python 项目

Python 代码无需交叉编译，但需要确保依赖在目标板上可用。将 Python 包同样放入 workspace：

```
~/workspace/
├── sdk_q1/
└── my_python_pkg/       # 你的 Python 包
    ├── package.xml
    ├── setup.py
    ├── setup.cfg
    ├── resource/
    │   └── my_python_pkg
    └── my_python_pkg/
        ├── __init__.py
        └── my_node.py
```

在容器内安装/打包：

```bash
cd /workspace/my_python_pkg
pip3 install -e .
# 或用 colcon 构建：
cd /workspace
colcon build --packages-select my_python_pkg
```

> Python 包本身不需要交叉编译，但如果依赖了 pybind11 / nanobind 等 C++ 扩展模块，则这些扩展会在 colcon build 时自动使用 aarch64 工具链编译。

#### 混合项目（C++ + Python 绑定）

如果项目同时包含 C++ 核心和 Python 绑定（如使用 nanobind/pybind11），按标准 ROS 2 包结构组织即可：

```
~/workspace/
└── my_hybrid_pkg/
    ├── CMakeLists.txt
    ├── package.xml
    ├── include/
    ├── src/              # C++ 源码
    └── my_hybrid_pkg/    # Python 包
        ├── __init__.py
        └── wrapper.py
```

`colcon build` 会自动处理 C++ 编译和 Python 绑定生成。

### 2.5 常见编译选项

```bash
# 编译指定包
colcon build --packages-select pkg_a pkg_b

# 编译指定包及其依赖
colcon build --packages-up-to pkg_a

# 清理后重新编译
rm -rf build/ install/ log/
colcon build

# 使用 cmake 参数
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release
```

---

## 3. 产物导出与部署

### 3.1 编译产物结构

`colcon build` 成功后，产物位于 workspace 内：

```
~/workspace/
├── sdk_q1/
│   ├── build/        # 编译中间文件（可删除）
│   ├── install/      # ★ 最终产物 — 部署到目标板的就是这个目录
│   └── log/          # 编译日志（可删除）
├── sdk_t1/
│   ├── build/
│   ├── install/
│   └── log/
```

`install/` 目录是部署所需的全部内容，包含：
- `lib/` — 编译生成的 `.so` 库文件和可执行文件
- `share/` — ROS 2 包的配置、launch 文件、参数文件等
- `local/lib/python3.10/` — Python 包和 C++ 扩展模块
- `setup.bash` / `local_setup.bash` — 环境变量加载脚本

### 3.2 导出产物到目标板

#### 部署前必须：修复路径

交叉编译容器中的 `AMENT_PREFIX_PATH` 指向 `/opt/aarch64-sysroot/opt/ros/humble`，`colcon build` 会将这个路径硬编码到生成的 `setup.bash` 等脚本中。目标板上的 ROS 2 实际安装在 `/opt/ros/humble`，所以部署前需要替换：

```bash
# 在宿主机上执行，将所有 install 目录中的 sysroot 路径替换为目标板实际路径
cd ~/workspace/sdk_q1
find . -path '*/install/*' -type f \
    -exec sed -i 's|/opt/aarch64-sysroot/opt/ros/humble|/opt/ros/humble|g' {} +
```

> 这一步每次编译后都需要执行。可以将其写成部署脚本的一部分。

#### 方式一：直接拷贝 install 目录

将 `install/` 目录整体拷贝到目标板（通过 SCP、U 盘、NFS 等）：

```bash
# 在宿主机上，将产物打包
cd ~/workspace/sdk_q1
tar -czf sdk_q1_install.tar.gz install/

# 通过 SCP 传输到目标板
scp sdk_q1_install.tar.gz user@target-board:/opt/ros_ws/

# 在目标板上解压
ssh user@target-board
cd /opt/ros_ws
tar -xzf sdk_q1_install.tar.gz
```

#### 方式二：推荐的完整部署结构

建议在目标板上按以下结构组织部署：

```
/opt/ros_ws/                    # 工作空间根目录
├── sdk_q1/
│   ├── install/                # 从交叉编译产物拷贝而来
│   └── config/                 # 运行时配置文件
├── sdk_t1/
│   ├── install/
│   └── config/
└── setup_env.sh                # 统一的环境加载脚本
```

### 3.3 在目标板上运行

登录目标板后，按以下步骤运行：

#### 方式一：直接执行二进制（推荐）

目标板上不一定安装了完整的 `ros2 run` 工具链，直接执行编译产物中的二进制文件更可靠：

```bash
# 1. 加载 ROS 2 基础环境
source /opt/ros/humble/setup.bash

# 2. 加载项目产物环境（设置 LD_LIBRARY_PATH 等）
source ~/sdk_q1/install/setup.bash

# 3. 直接执行二进制文件
~/sdk_q1/install/aimdk_examples_cpp/lib/aimdk_examples_cpp/play_audio \
    --ros-args -p file_name:=小星星.wav \
    -p file_path:=/robot/software/aimrt_agent/bin/cfg/q1/audio
```

> `source setup.bash` 仍然需要执行，它会设置 `LD_LIBRARY_PATH` 让运行时能找到编译产物中的 `.so` 库。

#### 方式二：使用 ros2 run（需要目标板安装了 ros2 CLI 工具）

```bash
# 1. 加载环境
source /opt/ros/humble/setup.bash
source ~/sdk_q1/install/setup.bash

# 2. 运行节点
ros2 run aimdk_examples_cpp play_audio --ros-args \
    -p file_name:=小星星.wav \
    -p file_path:=/robot/software/aimrt_agent/bin/cfg/q1/audio
```

> 建议将上述 `source` 命令写入 `~/.bashrc` 或 `/opt/ros_ws/setup_env.sh`，避免每次手动加载。

### 3.4 运行前检查清单

- [ ] 目标板已安装 ROS 2 Humble 基础环境
- [ ] ONNX Runtime 已部署到 `/usr/local/onnxruntime`（与编译时路径一致）
- [ ] `LD_LIBRARY_PATH` 包含 `/usr/local/onnxruntime/lib`
- [ ] 模型文件已放置到指定目录（根据项目配置）
- [ ] 网络/设备权限已正确配置

### 3.5 Windows 换行符问题

如果代码从 Windows 下载后再传到 Ubuntu 目标板，Shell 脚本可能带有 Windows 换行符（CRLF `\r\n`），导致执行报错：

```
/bin/bash^M: bad interpreter: No such file or directory
```

或

```
: command not found
```

#### 检测方法

```bash
# 检查文件是否包含 \r（Windows 换行符）
file setup.bash
# 如果输出包含 "CRLF line terminators"，说明有问题

# 或用 grep 检测
grep -q $'\r' setup.bash && echo "有 Windows 换行符" || echo "正常"
```

#### 解决方法

**方法一：使用 dos2unix（推荐）**
```bash
# 安装 dos2unix
sudo apt install dos2unix

# 转换单个文件
dos2unix setup.bash

# 批量转换 install 目录下所有文件
find install/ -type f -exec dos2unix {} +
```

**方法二：使用 sed**
```bash
# 转换单个文件
sed -i 's/\r$//' setup.bash

# 批量转换
find install/ -type f -exec sed -i 's/\r$//' {} +
```

**方法三：Git 自动转换（预防）**

在 Git 仓库根目录创建 `.gitattributes` 文件：
```
# 强制所有 .sh 文件使用 LF 换行
*.sh text eol=lf
*.bash text eol=lf

# 二进制文件保持原样
*.so binary
*.tgz binary
*.tar.gz binary
```

然后在 Windows 上配置 Git：
```bash
git config --global core.autocrlf false
```

> **建议：** 如果团队中有 Windows 用户，务必在仓库中添加 `.gitattributes` 文件，从源头避免换行符问题。

---

## 附录：平台差异速查

| 项目 | RK 平台 | Orin 平台 |
|------|---------|-----------|
| 基础镜像 | `ros:humble-ros-base` | `nvcr.io/nvidia/l4t-base:r36.2.0` |
| CUDA 支持 | 无 | CUDA 12.6 + cuDNN 9 + TensorRT |
| 镜像名称 | `cross-aarch64-rk` | `cross-aarch64-orin` |
| 镜像大小 | ~5.4 GB（压缩 ~1.3 GB） | ~44.6 GB（压缩 ~15.7 GB） |
| 适用场景 | 通用 ARM64 部署 | 需要 GPU 推理的 NVIDIA 平台 |
