# FindPhysFS.cmake - Windows + vcpkg

set(PHYSFS_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include")
set(PHYSFS_LIBRARY "C:/vcpkg/installed/x64-windows/lib/physfs.lib")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(PhysFS DEFAULT_MSG
    PHYSFS_LIBRARY
    PHYSFS_INCLUDE_DIR
)

mark_as_advanced(PHYSFS_LIBRARY PHYSFS_INCLUDE_DIR)