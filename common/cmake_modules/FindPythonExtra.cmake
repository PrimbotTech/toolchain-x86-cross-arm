if(PythonExtra_FOUND)
  return()
endif()

set(PythonExtra_FOUND TRUE)
set(PythonExtra_INCLUDE_DIRS "/opt/aarch64-sysroot/usr/include/python3.10")
set(PythonExtra_LIBRARIES "/opt/aarch64-sysroot/usr/lib/aarch64-linux-gnu/libpython3.10.so")

set(PYTHON_SOABI "cpython-310-aarch64-linux-gnu")
set(PYTHON_VERSION "3.10.12")
set(PYTHON_VERSION_MAJOR "3")
set(PYTHON_VERSION_MINOR "10")
set(PYTHON_VERSION_PATCH "12")

if(NOT TARGET PythonExtra::Module)
  add_library(PythonExtra::Module INTERFACE IMPORTED GLOBAL)
  set_target_properties(PythonExtra::Module PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "/opt/aarch64-sysroot/usr/include/python3.10"
    INTERFACE_LINK_LIBRARIES "/opt/aarch64-sysroot/usr/lib/aarch64-linux-gnu/libpython3.10.so"
  )
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(PythonExtra
  REQUIRED_VARS PythonExtra_LIBRARIES PythonExtra_INCLUDE_DIRS
)
