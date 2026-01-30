# FindZLIB.cmake - Windows + vcpkg (supports static and dynamic)

if(NOT DEFINED VCPKG_INSTALLED_DIR)
    set(VCPKG_INSTALLED_DIR "C:/vcpkg/installed")
endif()

if(USE_STATIC_LIBS)
    set(ZLIB_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows-static/include")
    set(ZLIB_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows-static/lib/zlib.lib")
else()
    set(ZLIB_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows/include")
    # Use debug library for Debug builds, release library otherwise
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(ZLIB_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows/debug/lib/zlibd.lib")
    else()
        set(ZLIB_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows/lib/zlib.lib")
    endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ZLIB DEFAULT_MSG
    ZLIB_LIBRARY
    ZLIB_INCLUDE_DIR
)

mark_as_advanced(ZLIB_LIBRARY ZLIB_INCLUDE_DIR)