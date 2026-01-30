# FindLuaJIT.cmake - Windows + vcpkg (supports static and dynamic)

if(NOT DEFINED VCPKG_INSTALLED_DIR)
    set(VCPKG_INSTALLED_DIR "C:/vcpkg/installed")
endif()

if(USE_STATIC_LIBS)
    set(LUAJIT_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows-static/include/luajit")
    set(LUAJIT_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows-static/lib/lua51.lib")
else()
    set(LUAJIT_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows/include/luajit")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND EXISTS "${VCPKG_INSTALLED_DIR}/x64-windows/debug/lib/lua51.lib")
        set(LUAJIT_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows/debug/lib/lua51.lib")
    else()
        set(LUAJIT_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows/lib/lua51.lib")
    endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LuaJIT DEFAULT_MSG
    LUAJIT_LIBRARY
    LUAJIT_INCLUDE_DIR
)

mark_as_advanced(LUAJIT_LIBRARY LUAJIT_INCLUDE_DIR)