# FindLibZip.cmake - force manual assignment (works in Visual Studio CMake)

set(LIBZIP_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include")
set(LIBZIP_LIBRARY "C:/vcpkg/installed/x64-windows/lib/zip.lib")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LibZip DEFAULT_MSG
    LIBZIP_LIBRARY
    LIBZIP_INCLUDE_DIR
)

mark_as_advanced(LIBZIP_LIBRARY LIBZIP_INCLUDE_DIR)