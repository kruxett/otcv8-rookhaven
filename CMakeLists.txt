set(OPENSSL_ROOT_DIR "C:/vcpkg/installed/x64-windows")
cmake_minimum_required(VERSION 3.25)
project(otclient)

include(GNUInstallDirs)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install" CACHE PATH "Install path prefix" FORCE)
endif()

set(OTCLIENT_VCPKG_ROOT "C:/vcpkg" CACHE PATH "Optional extra vcpkg root for client dependencies")
set(_otclient_triplet_default "x64-windows")
if(DEFINED VCPKG_TARGET_TRIPLET)
    set(_otclient_triplet "${VCPKG_TARGET_TRIPLET}")
else()
    set(_otclient_triplet "${_otclient_triplet_default}")
endif()

set(_otclient_extra_prefix "${OTCLIENT_VCPKG_ROOT}/installed/${_otclient_triplet}")
if(EXISTS "${_otclient_extra_prefix}")
    list(APPEND CMAKE_PREFIX_PATH "${_otclient_extra_prefix}")
endif()

if(CMAKE_BASE_NAME STREQUAL "em++")
    set(WASM ON)
endif()

set(CMAKE_CXX_STANDARD 17)

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

set(_CLIENT_RESOURCE_DIRS data modules)
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

function(otclient_install_runtime dll_name)
    set(_dll_path "${OTCLIENT_VCPKG_ROOT}/installed/${_otclient_triplet}/bin/${dll_name}.dll")
    if(EXISTS "${_dll_path}")
        install(FILES "${_dll_path}"
                DESTINATION .
                CONFIGURATIONS Release RelWithDebInfo MinSizeRel)
    endif()
endfunction()

set(_otclient_runtime_dlls
    glew32
    libssl-3-x64
    libcrypto-3-x64
    physfs
    lua51
    bz2
    zlib1
    zstd
    cryptopp)

foreach(_dll ${_otclient_runtime_dlls})
    otclient_install_runtime(${_dll})
endforeach()

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
