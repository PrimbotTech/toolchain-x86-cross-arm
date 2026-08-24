# x86下arm交叉编译容器使用

在宿主机目录 `~` 下面创建一个文件夹 `workspace`, 将 `sdk_q1` 和 `sdk_t1` 项目移动到此文件夹下面。

> rk镜像使用方法

```bash
gunzip -c rk-cross-aarch64.tar.gz | docker load
docker run -it --rm --net=host -v ~/workspace:/workspace  -w /workspace rk-cross-aarch64 bash
cd sdk_q1
colcon build
cd sdk_t1
colcon build
```

> orin镜像使用方法

```bash
gunzip -c orin-cross-aarch64.tar.gz | docker load
docker run -it --rm --net=host -v ~/workspace:/workspace  -w /workspace orin-cross-aarch64 bash
cd sdk_q1
colcon build
cd sdk_t1
colcon build
```