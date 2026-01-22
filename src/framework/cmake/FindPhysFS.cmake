# FindPhysFS.cmake - Windows + vcpkg (supports static and dynamic)

if(USE_STATIC_LIBS)
    set(PHYSFS_INCLUDE_DIR "C:/vcpkg/installed/x64-windows-static/include")
    set(PHYSFS_LIBRARY "C:/vcpkg/installed/x64-windows-static/lib/physfs-static.lib")
else()
    set(PHYSFS_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include")
    set(PHYSFS_LIBRARY "C:/vcpkg/installed/x64-windows/lib/physfs.lib")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(PhysFS DEFAULT_MSG
    PHYSFS_LIBRARY
    PHYSFS_INCLUDE_DIR
)

mark_as_advanced(PHYSFS_LIBRARY PHYSFS_INCLUDE_DIR)