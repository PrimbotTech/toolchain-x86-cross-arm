if(Python_FOUND)
  return()
endif()

set(Python_FOUND TRUE)
set(Python_Interpreter_FOUND TRUE)
set(Python_Development_FOUND TRUE)

set(Python_VERSION "3.10.12")
set(Python_VERSION_MAJOR "3")
set(Python_VERSION_MINOR "10")
set(Python_VERSION_PATCH "12")

set(Python_EXECUTABLE "/usr/bin/python3")
set(Python_INCLUDE_DIRS "/opt/aarch64-sysroot/usr/include/python3.10")
set(Python_LIBRARIES "/opt/aarch64-sysroot/usr/lib/aarch64-linux-gnu/libpython3.10.so")
set(Python_LIBRARY_DIRS "/opt/aarch64-sysroot/usr/lib/aarch64-linux-gnu")
set(Python_SOABI "cpython-310-aarch64-linux-gnu")
set(Python_SOSABI "abi3")

# 创建 imported targets（nanobind 需要）
if(NOT TARGET Python::Python)
  add_library(Python::Python SHARED IMPORTED GLOBAL)
  set_target_properties(Python::Python PROPERTIES
    IMPORTED_LOCATION "/opt/aarch64-sysroot/usr/lib/aarch64-linux-gnu/libpython3.10.so"
    INTERFACE_INCLUDE_DIRECTORIES "/opt/aarch64-sysroot/usr/include/python3.10"
  )
endif()

if(NOT TARGET Python::Module)
  add_library(Python::Module INTERFACE IMPORTED GLOBAL)
  set_target_properties(Python::Module PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "/opt/aarch64-sysroot/usr/include/python3.10"
    INTERFACE_LINK_LIBRARIES "/opt/aarch64-sysroot/usr/lib/aarch64-linux-gnu/libpython3.10.so"
  )
endif()

if(NOT TARGET Python::Interpreter)
  add_executable(Python::Interpreter IMPORTED GLOBAL)
  set_target_properties(Python::Interpreter PROPERTIES
    IMPORTED_LOCATION "/usr/bin/python3"
  )
endif()

foreach(_component IN LISTS Python_FIND_COMPONENTS)
  set(Python_${_component}_FOUND TRUE)
endforeach()
