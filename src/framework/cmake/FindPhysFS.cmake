# FindPhysFS.cmake - Windows + vcpkg (supports static and dynamic)

if(NOT DEFINED VCPKG_INSTALLED_DIR)
    set(VCPKG_INSTALLED_DIR "C:/vcpkg/installed")
endif()

if(USE_STATIC_LIBS)
    set(PHYSFS_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows-static/include")
    set(PHYSFS_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows-static/lib/physfs-static.lib")
else()
    set(PHYSFS_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows/include")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND EXISTS "${VCPKG_INSTALLED_DIR}/x64-windows/debug/lib/physfs.lib")
        set(PHYSFS_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows/debug/lib/physfs.lib")
    else()
        set(PHYSFS_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows/lib/physfs.lib")
    endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(PhysFS DEFAULT_MSG
    PHYSFS_LIBRARY
    PHYSFS_INCLUDE_DIR
)

mark_as_advanced(PHYSFS_LIBRARY PHYSFS_INCLUDE_DIR)