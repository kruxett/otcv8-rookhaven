# FindLuaJIT.cmake - Windows + vcpkg (supports static and dynamic)

if(USE_STATIC_LIBS)
    set(LUAJIT_INCLUDE_DIR "C:/vcpkg/installed/x64-windows-static/include/luajit")
    set(LUAJIT_LIBRARY "C:/vcpkg/installed/x64-windows-static/lib/lua51.lib")
else()
    set(LUAJIT_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include/luajit")
    set(LUAJIT_LIBRARY "C:/vcpkg/installed/x64-windows/lib/lua51.lib")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LuaJIT DEFAULT_MSG
    LUAJIT_LIBRARY
    LUAJIT_INCLUDE_DIR
)

mark_as_advanced(LUAJIT_LIBRARY LUAJIT_INCLUDE_DIR)