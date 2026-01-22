# FindZLIB.cmake - Windows + vcpkg (supports static and dynamic)

if(USE_STATIC_LIBS)
    set(ZLIB_INCLUDE_DIR "C:/vcpkg/installed/x64-windows-static/include")
    set(ZLIB_LIBRARY "C:/vcpkg/installed/x64-windows-static/lib/zlib.lib")
else()
    set(ZLIB_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include")
    set(ZLIB_LIBRARY "C:/vcpkg/installed/x64-windows/lib/zlib.lib")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ZLIB DEFAULT_MSG
    ZLIB_LIBRARY
    ZLIB_INCLUDE_DIR
)

mark_as_advanced(ZLIB_LIBRARY ZLIB_INCLUDE_DIR)