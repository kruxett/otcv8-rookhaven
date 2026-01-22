# FindLibZip.cmake - Windows + vcpkg (supports static and dynamic)

if(USE_STATIC_LIBS)
    set(LIBZIP_INCLUDE_DIR_ZIP "C:/vcpkg/installed/x64-windows-static/include")
    set(LIBZIP_INCLUDE_DIR_ZIPCONF "C:/vcpkg/installed/x64-windows-static/include")
    set(LIBZIP_INCLUDE_DIR "C:/vcpkg/installed/x64-windows-static/include")
    # Static libzip requires its dependencies: zstd, lzma, bzip2, zlib
    set(LIBZIP_LIBRARY 
        "C:/vcpkg/installed/x64-windows-static/lib/zip.lib"
        "C:/vcpkg/installed/x64-windows-static/lib/zstd.lib"
        "C:/vcpkg/installed/x64-windows-static/lib/lzma.lib"
    )
else()
    set(LIBZIP_INCLUDE_DIR_ZIP "C:/vcpkg/installed/x64-windows/include")
    set(LIBZIP_INCLUDE_DIR_ZIPCONF "C:/vcpkg/installed/x64-windows/include")
    set(LIBZIP_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include")
    set(LIBZIP_LIBRARY "C:/vcpkg/installed/x64-windows/lib/zip.lib")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LibZip DEFAULT_MSG
    LIBZIP_LIBRARY
    LIBZIP_INCLUDE_DIR
)

mark_as_advanced(LIBZIP_LIBRARY LIBZIP_INCLUDE_DIR)