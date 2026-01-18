# FindLuaJIT.cmake - Windows + vcpkg

set(LUAJIT_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include")
set(LUAJIT_LIBRARY "C:/vcpkg/installed/x64-windows/lib/lua51.lib")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LuaJIT DEFAULT_MSG
    LUAJIT_LIBRARY
    LUAJIT_INCLUDE_DIR
)

mark_as_advanced(LUAJIT_LIBRARY LUAJIT_INCLUDE_DIR)