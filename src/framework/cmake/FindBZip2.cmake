# FindBZip2.cmake - Windows + vcpkg (supports static and dynamic)

if(USE_STATIC_LIBS)
    set(BZIP2_INCLUDE_DIR "C:/vcpkg/installed/x64-windows-static/include")
    set(BZIP2_LIBRARIES "C:/vcpkg/installed/x64-windows-static/lib/bz2.lib")
else()
    set(BZIP2_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include")
    set(BZIP2_LIBRARIES "C:/vcpkg/installed/x64-windows/lib/bz2.lib")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(BZip2 DEFAULT_MSG
    BZIP2_LIBRARIES
    BZIP2_INCLUDE_DIR
)

mark_as_advanced(BZIP2_LIBRARIES BZIP2_INCLUDE_DIR)