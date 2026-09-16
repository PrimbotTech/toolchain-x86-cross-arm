list(APPEND CMAKE_MODULE_PATH "/opt/cmake_modules")
# 1. 目标系统设置
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# 2. 交叉编译器
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)

# 3. Sysroot 路径（关键）
set(SYSROOT_PATH /opt/aarch64-sysroot)
#set(CMAKE_SYSROOT ${SYSROOT_PATH})

# 4. 查找根路径（让 CMake 在 sysroot 内搜索）
set(CMAKE_FIND_ROOT_PATH ${SYSROOT_PATH})

# 5. 查找模式：只在 sysroot 内查找库、头文件、包配置
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

# 6. 设置包搜索路径（关键！让 find_package 能找到 ROS 2 的 .cmake 文件）
#    注意：这里使用 SYSROOT_PATH 变量，而不是 CMAKE_SYSROOT
list(APPEND CMAKE_PREFIX_PATH ${SYSROOT_PATH}/opt/ros/humble)

# 7. 可选：显式指定 Python 路径（避免 Python 查找时忽略 sysroot）
set(Python3_ROOT_DIR ${SYSROOT_PATH}/usr)
set(Python3_INCLUDE_DIR ${SYSROOT_PATH}/usr/include/python3.10)
set(Python3_LIBRARY ${SYSROOT_PATH}/usr/lib/aarch64-linux-gnu/libpython3.10.so)

# 8. 可选：设置 CMAKE_FIND_ROOT_PATH 的附加路径（用于查找 ROS 2 的独立包）
list(APPEND CMAKE_FIND_ROOT_PATH ${SYSROOT_PATH}/opt/ros/humble)

# 9. 调试信息（可选，有助于排查问题）
message(STATUS "Cross-compiling for aarch64 with sysroot: ${SYSROOT_PATH}")
message(STATUS "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")

# 10. PythonExtra 变量（旧版 FindPythonLibs 使用）
set(PYTHON_LIBRARY ${SYSROOT_PATH}/usr/lib/aarch64-linux-gnu/libpython3.10.so)
set(PYTHON_INCLUDE_DIR ${SYSROOT_PATH}/usr/include/python3.10)
set(PythonExtra_LIBRARIES ${SYSROOT_PATH}/usr/lib/aarch64-linux-gnu/libpython3.10.so)

# 11. Python 变量（FindPython.cmake 使用，注意没有 "3"）
set(Python_ROOT_DIR ${SYSROOT_PATH}/usr)
set(Python_INCLUDE_DIR ${SYSROOT_PATH}/usr/include/python3.10)
set(Python_LIBRARY ${SYSROOT_PATH}/usr/lib/aarch64-linux-gnu/libpython3.10.so)

# 12. Development.Module 组件（nanobind 需要）
set(Python_Development.Module_FOUND TRUE CACHE BOOL "" FORCE)
set(Python_Development_FOUND TRUE CACHE BOOL "" FORCE)

set(CMAKE_C_FLAGS_INIT "--sysroot=${SYSROOT_PATH}")
set(CMAKE_CXX_FLAGS_INIT "--sysroot=${SYSROOT_PATH}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "--sysroot=${SYSROOT_PATH}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "--sysroot=${SYSROOT_PATH}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "--sysroot=${SYSROOT_PATH}")
set(Python_INCLUDE_DIRS "${SYSROOT_PATH}/usr/include/python3.10" CACHE PATH "" FORCE)
set(Python_LIBRARIES "${SYSROOT_PATH}/usr/lib/aarch64-linux-gnu/libpython3.10.so" CACHE FILEPATH "" FORCE)

# 13. FindPython CACHE FORCE - 强制覆盖 find_package 结果
set(Python_INCLUDE_DIRS "${SYSROOT_PATH}/usr/include/python3.10" CACHE PATH "" FORCE)
set(Python_LIBRARIES "${SYSROOT_PATH}/usr/lib/aarch64-linux-gnu/libpython3.10.so" CACHE FILEPATH "" FORCE)
set(Python_LIBRARY_RELEASE "${SYSROOT_PATH}/usr/lib/aarch64-linux-gnu/libpython3.10.so" CACHE FILEPATH "" FORCE)
set(Python_VERSION "3.10.12" CACHE STRING "" FORCE)
set(Python_VERSION_MAJOR "3" CACHE STRING "" FORCE)
set(Python_VERSION_MINOR "10" CACHE STRING "" FORCE)
set(Python_VERSION_PATCH "12" CACHE STRING "" FORCE)
set(Python_EXECUTABLE "/usr/bin/python3" CACHE FILEPATH "" FORCE)
set(Python_Development.Module_FOUND TRUE CACHE BOOL "" FORCE)
set(Python_Development_FOUND TRUE CACHE BOOL "" FORCE)
set(Python_SOABI "cpython-310-aarch64-linux-gnu" CACHE STRING "" FORCE)
set(PYTHON_SOABI "cpython-310-aarch64-linux-gnu" CACHE STRING "" FORCE)
