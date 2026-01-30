# FindBZip2.cmake - Windows + vcpkg (supports static and dynamic)

if(NOT DEFINED VCPKG_INSTALLED_DIR)
    set(VCPKG_INSTALLED_DIR "C:/vcpkg/installed")
endif()

if(USE_STATIC_LIBS)
    set(BZIP2_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows-static/include")
    set(BZIP2_LIBRARIES "${VCPKG_INSTALLED_DIR}/x64-windows-static/lib/bz2.lib")
else()
    set(BZIP2_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows/include")
    # Use debug library for Debug builds, release library otherwise
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(BZIP2_LIBRARIES "${VCPKG_INSTALLED_DIR}/x64-windows/debug/lib/bz2d.lib")
    else()
        set(BZIP2_LIBRARIES "${VCPKG_INSTALLED_DIR}/x64-windows/lib/bz2.lib")
    endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(BZip2 DEFAULT_MSG
    BZIP2_LIBRARIES
    BZIP2_INCLUDE_DIR
)

mark_as_advanced(BZIP2_LIBRARIES BZIP2_INCLUDE_DIR)