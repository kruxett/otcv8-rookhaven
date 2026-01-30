# FindLibZip.cmake - Windows + vcpkg (supports static and dynamic)

if(NOT DEFINED VCPKG_INSTALLED_DIR)
    set(VCPKG_INSTALLED_DIR "C:/vcpkg/installed")
endif()

if(USE_STATIC_LIBS)
    set(LIBZIP_INCLUDE_DIR_ZIP "${VCPKG_INSTALLED_DIR}/x64-windows-static/include")
    set(LIBZIP_INCLUDE_DIR_ZIPCONF "${VCPKG_INSTALLED_DIR}/x64-windows-static/include")
    set(LIBZIP_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows-static/include")
    # Static libzip requires its dependencies: zstd, lzma, bzip2, zlib
    set(LIBZIP_LIBRARY 
        "${VCPKG_INSTALLED_DIR}/x64-windows-static/lib/zip.lib"
        "${VCPKG_INSTALLED_DIR}/x64-windows-static/lib/zstd.lib"
        "${VCPKG_INSTALLED_DIR}/x64-windows-static/lib/lzma.lib"
    )
else()
    set(LIBZIP_INCLUDE_DIR_ZIP "${VCPKG_INSTALLED_DIR}/x64-windows/include")
    set(LIBZIP_INCLUDE_DIR_ZIPCONF "${VCPKG_INSTALLED_DIR}/x64-windows/include")
    set(LIBZIP_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows/include")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND EXISTS "${VCPKG_INSTALLED_DIR}/x64-windows/debug/lib/zip.lib")
        set(LIBZIP_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows/debug/lib/zip.lib")
    else()
        set(LIBZIP_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows/lib/zip.lib")
    endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LibZip DEFAULT_MSG
    LIBZIP_LIBRARY
    LIBZIP_INCLUDE_DIR
)

mark_as_advanced(LIBZIP_LIBRARY LIBZIP_INCLUDE_DIR)