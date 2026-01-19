set(OPENSSL_ROOT_DIR "C:/vcpkg/installed/x64-windows-static")
set(CMAKE_C_COMPILER   "C:/Program Files/Microsoft Visual Studio/18/Community/VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64/cl.exe" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER "C:/Program Files/Microsoft Visual Studio/18/Community/VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64/cl.exe" CACHE STRING "" FORCE)
set(CMAKE_RC_COMPILER  "C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/rc.exe" CACHE FILEPATH "" FORCE)
set(CMAKE_MT           "C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/mt.exe" CACHE FILEPATH "" FORCE)

# Force linker to use x64 libraries
set(_MSVC_LIB_X64 "C:/Program Files/Microsoft Visual Studio/18/Community/VC/Tools/MSVC/14.50.35717/lib/x64")
set(_WINSDK_UCRT_X64 "C:/Program Files (x86)/Windows Kits/10/Lib/10.0.26100.0/ucrt/x64")
set(_WINSDK_UM_X64   "C:/Program Files (x86)/Windows Kits/10/Lib/10.0.26100.0/um/x64")
set(CMAKE_EXE_LINKER_FLAGS        "/machine:x64 /LIBPATH:\"${_MSVC_LIB_X64}\" /LIBPATH:\"${_WINSDK_UCRT_X64}\" /LIBPATH:\"${_WINSDK_UM_X64}\"" CACHE STRING "" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS     "${CMAKE_EXE_LINKER_FLAGS}" CACHE STRING "" FORCE)
set(CMAKE_MODULE_LINKER_FLAGS     "${CMAKE_EXE_LINKER_FLAGS}" CACHE STRING "" FORCE)
cmake_minimum_required(VERSION 3.25)
project(otclient)

# Prefer NEW behavior for _ROOT variables
if(POLICY CMP0144)
  cmake_policy(SET CMP0144 NEW)
endif()

include(GNUInstallDirs)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install" CACHE PATH "Install path prefix" FORCE)
endif()

# Use static libraries for cleaner deployment
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build shared libraries" FORCE)
# Force vcpkg to use static triplet for both host/target and point to new vcpkg installation
set(VCPKG_TARGET_TRIPLET "x64-windows-static" CACHE STRING "" FORCE)
set(VCPKG_HOST_TRIPLET   "x64-windows-static" CACHE STRING "" FORCE)
set(VCPKG_ROOT           "C:/vcpkg" CACHE PATH "" FORCE)
set(VCPKG_INSTALLED_DIR  "C:/vcpkg/installed" CACHE PATH "" FORCE)
set(VCPKG_BUILD_TYPE     "release" CACHE STRING "" FORCE)
# Prefer static OpenSSL/Zlib/BZip2 roots explicitly
set(OPENSSL_ROOT_DIR "${VCPKG_INSTALLED_DIR}/x64-windows-static" CACHE PATH "" FORCE)
set(OPENSSL_INCLUDE_DIR "${OPENSSL_ROOT_DIR}/include" CACHE PATH "" FORCE)
set(OPENSSL_USE_STATIC_LIBS TRUE CACHE BOOL "" FORCE)
set(OPENSSL_SSL_LIBRARY "${OPENSSL_ROOT_DIR}/lib/libssl.lib" CACHE FILEPATH "" FORCE)
set(OPENSSL_CRYPTO_LIBRARY "${OPENSSL_ROOT_DIR}/lib/libcrypto.lib" CACHE FILEPATH "" FORCE)
set(ZLIB_ROOT        "${VCPKG_INSTALLED_DIR}/x64-windows-static" CACHE PATH "" FORCE)
set(ZLIB_INCLUDE_DIR "${ZLIB_ROOT}/include" CACHE PATH "" FORCE)
set(ZLIB_USE_STATIC_LIBS ON CACHE BOOL "" FORCE)
set(ZLIB_LIBRARY     "${ZLIB_ROOT}/lib/zlib.lib" CACHE FILEPATH "" FORCE)
set(BZIP2_ROOT       "${VCPKG_INSTALLED_DIR}/x64-windows-static" CACHE PATH "" FORCE)
set(BZIP2_INCLUDE_DIR "${BZIP2_ROOT}/include" CACHE PATH "" FORCE)
set(BZIP2_LIBRARY    "${BZIP2_ROOT}/lib/bz2.lib" CACHE FILEPATH "" FORCE)
# libzip/luajit/physfs explicit release libs
set(LIBZIP_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows-static/lib/zip.lib" CACHE FILEPATH "" FORCE)
set(LIBZIP_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows-static/include" CACHE PATH "" FORCE)
set(LUA_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows-static/include" CACHE PATH "" FORCE)
set(LUA_LIBRARIES "${VCPKG_INSTALLED_DIR}/x64-windows-static/lib/lua51.lib" CACHE FILEPATH "" FORCE)
set(LUAJIT_INCLUDE_DIR "${VCPKG_INSTALLED_DIR}/x64-windows-static/include" CACHE PATH "" FORCE)
set(LUAJIT_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows-static/lib/lua51.lib" CACHE FILEPATH "" FORCE)
set(LUAJIT_LIBRARIES "${LUAJIT_LIBRARY}" CACHE FILEPATH "" FORCE)
set(PHYSFS_LIBRARY "${VCPKG_INSTALLED_DIR}/x64-windows-static/lib/physfs-static.lib" CACHE FILEPATH "" FORCE)
# Avoid copying random DLLs; we want a static, clean deploy
set(VCPKG_APPLOCAL_DEPS OFF CACHE BOOL "" FORCE)

# Ignore any other vcpkg installations to avoid conflicts
list(APPEND CMAKE_IGNORE_PATH "C:/vcpkg-server")
# Explicitly ignore dynamic triplet paths so find_package doesn't grab them
list(APPEND CMAKE_IGNORE_PATH
    "C:/vcpkg/installed/x64-windows" "C:/vcpkg/installed/x64-windows/debug"
    "C:/vcpkg-server/installed/x64-windows" "C:/vcpkg-server/installed/x64-windows/debug")

# Hard-set prefix path to static triplet only (avoid x64-windows picks)
set(CMAKE_PREFIX_PATH "${VCPKG_INSTALLED_DIR}/x64-windows-static" CACHE STRING "" FORCE)
# Force CMake find_package to search only in static root and ignore registry/env
set(CMAKE_FIND_ROOT_PATH "${VCPKG_INSTALLED_DIR}/x64-windows-static" CACHE STRING "" FORCE)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_FIND_USE_PACKAGE_REGISTRY OFF)
set(CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY ON)
set(CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH OFF)

if(CMAKE_BASE_NAME STREQUAL "em++")
    set(WASM ON)
endif()

set(CMAKE_CXX_STANDARD 17)

# Default login endpoint baked into the binary (ip:port:version)
set(DEFAULT_SERVER_ENDPOINT "testserver.rookhaven-ot.com:7171:860" CACHE STRING "Default login endpoint (ip:port:version) baked into the client executable")

# default build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release")
endif()

option(FRAMEWORK_SOUND "Use SOUND " OFF)
option(FRAMEWORK_GRAPHICS "Use GRAPHICS " ON)
option(FRAMEWORK_XML "Use XML " ON)
option(FRAMEWORK_NET "Use NET " ON)

include(src/framework/CMakeLists.txt)
include(src/client/CMakeLists.txt)

# functions map for reading backtraces
if(NOT APPLE AND NOT WASM AND NOT MSVC)
    set(CMAKE_CXX_LINK_FLAGS "${CMAKE_CXX_LINK_FLAGS} -no-pie -Wl,-Map=${PROJECT_NAME}.map")
endif()

set(executable_SOURCES
    src/main.cpp
)

# add executable icon for win32 platforms
if(WIN32)
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/otcicon.res
        COMMAND ${CMAKE_RC_COMPILER}
            /I${CMAKE_CURRENT_SOURCE_DIR}/src
            /fo${CMAKE_CURRENT_BINARY_DIR}/otcicon.res
            ${CMAKE_CURRENT_SOURCE_DIR}/src/otcicon.rc
    )
    set(executable_SOURCES ${executable_SOURCES} ${CMAKE_CURRENT_BINARY_DIR}/otcicon.res)
endif()

if(VERSION)
    add_definitions(-D"VERSION=\\"${VERSION}\\"")
endif()

# add client executable
add_executable(${PROJECT_NAME} ${framework_SOURCES} ${client_SOURCES} ${executable_SOURCES})
target_link_libraries(${PROJECT_NAME} ${framework_LIBRARIES})

# Bake the default server endpoint into the executable so it isn't present in Lua sources
target_compile_definitions(${PROJECT_NAME} PRIVATE DEFAULT_SERVER_ENDPOINT="${DEFAULT_SERVER_ENDPOINT}")

if(MSVC)
    target_link_options(${PROJECT_NAME} PRIVATE
        $<$<CONFIG:Release>:/SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup>)
endif()

if(APPLE AND USE_STATIC_LIBS)
    target_link_libraries(${PROJECT_NAME} "-framework Foundation" "-framework IOKit")
endif()

# Installation rules
install(TARGETS ${PROJECT_NAME}
        RUNTIME DESTINATION .
        BUNDLE DESTINATION .
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})

set(_CLIENT_RESOURCE_DIRS data modules layouts)
foreach(_resource_dir IN LISTS _CLIENT_RESOURCE_DIRS)
    if(EXISTS "${CMAKE_SOURCE_DIR}/${_resource_dir}")
        install(DIRECTORY "${CMAKE_SOURCE_DIR}/${_resource_dir}"
                DESTINATION .
                USE_SOURCE_PERMISSIONS)
    endif()
endforeach()

if(EXISTS "${CMAKE_SOURCE_DIR}/init.lua")
    install(FILES "${CMAKE_SOURCE_DIR}/init.lua" DESTINATION .)
endif()

# Copy required DLLs from vcpkg to the binary directory and install directory
set(VCPKG_DLL_PATH "${VCPKG_INSTALLED_DIR}/x64-windows/bin")
if(EXISTS "${VCPKG_DLL_PATH}")
    file(GLOB VCPKG_DLLS "${VCPKG_DLL_PATH}/*.dll")
    foreach(DLL ${VCPKG_DLLS})
        # Copy to build directory for running locally
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different "${DLL}" "$<TARGET_FILE_DIR:${PROJECT_NAME}>/"
            COMMENT "Copying ${DLL} to build directory")
        # Install the DLLs
        install(FILES "${DLL}" DESTINATION .)
    endforeach()
endif()

# Packaging helper (ninja package_release / Build ? Package Release)
if(CMAKE_CONFIGURATION_TYPES)
    set(_package_suffix "$<CONFIG>")
else()
    set(_package_suffix "${CMAKE_BUILD_TYPE}")
endif()
set(_package_archive "${CMAKE_BINARY_DIR}/${PROJECT_NAME}-${_package_suffix}.zip")

add_custom_target(package_release
    COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_INSTALL_PREFIX}"
    COMMAND ${CMAKE_COMMAND} -E rm -f "${_package_archive}"
    COMMAND ${CMAKE_COMMAND} -E tar "cf" "${_package_archive}" --format=zip -C "${CMAKE_INSTALL_PREFIX}" .
    USES_TERMINAL
    COMMENT "Creating redistributable archive at ${_package_archive}")
add_dependencies(package_release install)
