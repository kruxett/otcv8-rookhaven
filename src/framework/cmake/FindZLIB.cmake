# FindZLIB.cmake - force manual assignment (works in Visual Studio CMake)

set(ZLIB_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include")
set(ZLIB_LIBRARY "C:/vcpkg/installed/x64-windows/lib/zlib.lib")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ZLIB DEFAULT_MSG
    ZLIB_LIBRARY
    ZLIB_INCLUDE_DIR
)

mark_as_advanced(ZLIB_LIBRARY ZLIB_INCLUDE_DIR)