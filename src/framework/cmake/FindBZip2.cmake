# FindBZip2.cmake - force manual assignment for Visual Studio + vcpkg

set(BZIP2_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include")
set(BZIP2_LIBRARIES "C:/vcpkg/installed/x64-windows/lib/bz2.lib")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(BZip2 DEFAULT_MSG
    BZIP2_LIBRARIES
    BZIP2_INCLUDE_DIR
)

mark_as_advanced(BZIP2_LIBRARIES BZIP2_INCLUDE_DIR)