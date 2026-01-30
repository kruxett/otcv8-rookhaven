unset(OPENSSL_ROOT_DIR CACHE)
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

# IMPORTANT: Set vcpkg paths BEFORE project() so toolchain file can use them
# These are now handled by CMakePresets.json - don't override them here
#if(NOT DEFINED VCPKG_ROOT)
#    set(VCPKG_ROOT "C:/vcpkg-client" CACHE PATH "" FORCE)
#endif()
#if(NOT DEFINED VCPKG_INSTALLED_DIR)
#    set(VCPKG_INSTALLED_DIR "${VCPKG_ROOT}/installed" CACHE PATH "" FORCE)
#endif()

# Explicitly ignore the server vcpkg to avoid conflicts
list(APPEND CMAKE_IGNORE_PATH
    "C:/vcpkg"
    "C:/vcpkg/installed"
    "C:/vcpkg/installed/x64-windows"
    "C:/vcpkg/installed/x64-windows/lib"
    "C:/vcpkg/installed/x64-windows/debug/lib"
    "C:/vcpkg/installed/x64-windows-static"
)

cmake_minimum_required(VERSION 3.25)
project(otclient)

# Prefer NEW behavior for _ROOT variables
if(POLICY CMP0144)
  cmake_policy(SET CMP0144 NEW)
endif()

include(GNUInstallDirs)

# Force dynamic Boost (and other libs) for Debug, static for Release
# These will be set properly based on USE_STATIC_LIBS option below
if(USE_STATIC_LIBS)
    set(Boost_USE_STATIC_LIBS ON CACHE BOOL "" FORCE)
    set(Boost_USE_STATIC_RUNTIME ON CACHE BOOL "" FORCE)
else()
    set(Boost_USE_STATIC_LIBS OFF CACHE BOOL "" FORCE)
    set(Boost_USE_STATIC_RUNTIME OFF CACHE BOOL "" FORCE)
endif()
set(Boost_USE_MULTITHREADED ON CACHE BOOL "" FORCE)
set(Boost_NO_BOOST_CMAKE ON CACHE BOOL "" FORCE)

# MSVC runtime: /MT for static Release, /MD for dynamic Debug
if(USE_STATIC_LIBS)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    set(VCPKG_TARGET_TRIPLET "x64-windows-static" CACHE STRING "" FORCE)
    set(VCPKG_HOST_TRIPLET   "x64-windows-static" CACHE STRING "" FORCE)
    set(CMAKE_PREFIX_PATH "${VCPKG_INSTALLED_DIR}/x64-windows-static" CACHE STRING "" FORCE)
else()
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
    set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
    set(VCPKG_TARGET_TRIPLET "x64-windows" CACHE STRING "" FORCE)
    set(VCPKG_HOST_TRIPLET   "x64-windows" CACHE STRING "" FORCE)
    set(CMAKE_PREFIX_PATH "${VCPKG_INSTALLED_DIR}/x64-windows" CACHE STRING "" FORCE)
endif()
# VCPKG_ROOT and VCPKG_INSTALLED_DIR are now set before project()
# Allow vcpkg to use debug libraries for debug builds
# set(VCPKG_BUILD_TYPE     "release" CACHE STRING "" FORCE)
# CMAKE_PREFIX_PATH is already set in the if/else block above
set(CMAKE_FIND_ROOT_PATH "" CACHE STRING "" FORCE)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
set(CMAKE_FIND_USE_PACKAGE_REGISTRY ON)
set(CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY OFF)
set(CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH ON)
set(CMAKE_FIND_LIBRARY_SUFFIXES ".lib" CACHE STRING "" FORCE)

# Set triplet-dependent paths
if(USE_STATIC_LIBS)
    set(_VCPKG_TRIPLET_DIR "${VCPKG_INSTALLED_DIR}/x64-windows-static")
else()
    set(_VCPKG_TRIPLET_DIR "${VCPKG_INSTALLED_DIR}/x64-windows")
endif()

unset(Boost_ROOT CACHE)
unset(BOOST_ROOT CACHE)
set(BOOST_ROOT "${_VCPKG_TRIPLET_DIR}" CACHE PATH "" FORCE)
unset(Boost_INCLUDE_DIR CACHE)
set(Boost_INCLUDE_DIR "${_VCPKG_TRIPLET_DIR}/include" CACHE PATH "" FORCE)
unset(Boost_LIBRARIES CACHE)
unset(Boost_LIBRARY_DIR CACHE)
unset(Boost_LIBRARY_DIR_DEBUG CACHE)
unset(Boost_LIBRARY_DIR_RELEASE CACHE)

unset(OPENSSL_ROOT_DIR CACHE)
set(OPENSSL_ROOT_DIR "${_VCPKG_TRIPLET_DIR}" CACHE PATH "" FORCE)
if(USE_STATIC_LIBS)
    set(OPENSSL_USE_STATIC_LIBS ON CACHE BOOL "" FORCE)
else()
    set(OPENSSL_USE_STATIC_LIBS OFF CACHE BOOL "" FORCE)
endif()

unset(BZIP2_ROOT CACHE)
unset(BZIP2_LIBRARY CACHE)
unset(BZIP2_INCLUDE_DIR CACHE)
set(BZIP2_ROOT "${_VCPKG_TRIPLET_DIR}" CACHE PATH "" FORCE)

unset(GLEW_ROOT CACHE)
unset(GLEW_LIBRARY CACHE)
unset(GLEW_LIBRARY_DEBUG CACHE)
unset(GLEW_LIBRARY_RELEASE CACHE)
if(USE_STATIC_LIBS)
    set(GLEW_USE_STATIC_LIBS ON CACHE BOOL "" FORCE)
else()
    set(GLEW_USE_STATIC_LIBS OFF CACHE BOOL "" FORCE)
endif()
set(GLEW_ROOT "${_VCPKG_TRIPLET_DIR}" CACHE PATH "" FORCE)

# Avoid picking wrong triplet libraries
if(USE_STATIC_LIBS)
    # Static build: ignore dynamic triplet
    list(APPEND CMAKE_IGNORE_PATH
        "${VCPKG_INSTALLED_DIR}/x64-windows"
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug"
        "${VCPKG_INSTALLED_DIR}/x64-windows/lib"
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/lib"
        "${VCPKG_INSTALLED_DIR}/x64-windows/bin"
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin")
else()
    # Dynamic build: ignore static triplet
    list(APPEND CMAKE_IGNORE_PATH
        "${VCPKG_INSTALLED_DIR}/x64-windows-static"
        "${VCPKG_INSTALLED_DIR}/x64-windows-static/debug"
        "${VCPKG_INSTALLED_DIR}/x64-windows-static/lib"
        "${VCPKG_INSTALLED_DIR}/x64-windows-static/debug/lib"
        "${VCPKG_INSTALLED_DIR}/x64-windows-static/bin"
        "${VCPKG_INSTALLED_DIR}/x64-windows-static/debug/bin"
        "${VCPKG_INSTALLED_DIR}/x64-windows-static/include"
        "${VCPKG_INSTALLED_DIR}/x64-windows-static/debug/include"
        "${VCPKG_INSTALLED_DIR}/installed/x64-windows-static"
        "${VCPKG_INSTALLED_DIR}/installed/x64-windows-static/debug"
        "${VCPKG_INSTALLED_DIR}/installed/x64-windows-static/lib"
        "${VCPKG_INSTALLED_DIR}/installed/x64-windows-static/debug/lib"
        "${VCPKG_INSTALLED_DIR}/installed/x64-windows-static/bin"
        "${VCPKG_INSTALLED_DIR}/installed/x64-windows-static/debug/bin"
        "${VCPKG_INSTALLED_DIR}/installed/x64-windows-static/include"
        "${VCPKG_INSTALLED_DIR}/installed/x64-windows-static/debug/include")
endif()

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

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}" CACHE PATH "Install path prefix" FORCE)
endif()

set(CLIENT_TARGET RookhavenClient)
set(RUNTIME_DATA_ZIP_PASSWORD "G7r!v9Q#t2ZpL4xM" CACHE STRING "Optional password for data.zip packaging")

option(FRAMEWORK_SOUND "Use SOUND " OFF)
option(FRAMEWORK_GRAPHICS "Use GRAPHICS " ON)
option(FRAMEWORK_XML "Use XML " ON)
option(FRAMEWORK_NET "Use NET " ON)

include(src/framework/CMakeLists.txt)
include(src/client/CMakeLists.txt)

# functions map for reading backtraces
if(NOT APPLE AND NOT WASM AND NOT MSVC)
    set(CMAKE_CXX_LINK_FLAGS "${CMAKE_CXX_LINK_FLAGS} -no-pie -Wl,-Map=${CLIENT_TARGET}.map")
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
add_executable(${CLIENT_TARGET} ${framework_SOURCES} ${client_SOURCES} ${executable_SOURCES})
target_link_libraries(${CLIENT_TARGET} ${framework_LIBRARIES})

# Bake the default server endpoint into the executable so it isn't present in Lua sources
target_compile_definitions(${CLIENT_TARGET} PRIVATE
    DEFAULT_SERVER_ENDPOINT="${DEFAULT_SERVER_ENDPOINT}"
    RUNTIME_DLL_RELATIVE="lib")

# Disable vcpkg applocal.ps1 completely - we handle DLLs ourselves in lib/
set(VCPKG_APPLOCAL_DEPS OFF CACHE BOOL "" FORCE)

if(MSVC)
    target_link_options(${CLIENT_TARGET} PRIVATE
        $<$<CONFIG:Release>:/SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup>)

    if(WIN32)
        if(USE_STATIC_LIBS)
            # Static linking: no delay-load needed, but need additional system libs
            # for OpenSSL static linking
            target_link_libraries(${CLIENT_TARGET} crypt32 ws2_32)
        else()
            # Dynamic linking: delay-load is required for a strict "exe + lib\\*.dll" layout,
            # because these DLLs would otherwise be implicitly loaded before main() runs.
            # Note: libcrypto-3-x64.dll is NOT delay-loaded because it's needed before main().
            target_link_libraries(${CLIENT_TARGET} $<$<CONFIG:Release>:delayimp>)
            target_link_options(${CLIENT_TARGET} PRIVATE
                $<$<CONFIG:Release>:/DELAY:UNLOAD>
                $<$<CONFIG:Release>:/DELAYLOAD:bz2.dll>
                $<$<CONFIG:Release>:/DELAYLOAD:libssl-3-x64.dll>
                $<$<CONFIG:Release>:/DELAYLOAD:lua51.dll>
                $<$<CONFIG:Release>:/DELAYLOAD:physfs.dll>
                $<$<CONFIG:Release>:/DELAYLOAD:zip.dll>
                $<$<CONFIG:Release>:/DELAYLOAD:zlib1.dll>
                $<$<CONFIG:Release>:/DELAYLOAD:boost_filesystem-vc145-mt-x64-1_90.dll>
                $<$<CONFIG:Release>:/DELAYLOAD:boost_system-vc145-mt-x64-1_90.dll>
                $<$<CONFIG:Release>:/DELAYLOAD:boost_atomic-vc145-mt-x64-1_90.dll>)
        endif()
    endif()
endif()

if(APPLE AND USE_STATIC_LIBS)
    target_link_libraries(${CLIENT_TARGET} "-framework Foundation" "-framework IOKit")
endif()

function(collect_runtime_deps TARGET OUT_DIR)
    set(options)
    set(oneValueArgs ZIP_DATA_PASSWORD)
    cmake_parse_arguments(CRD "${options}" "${oneValueArgs}" "" ${ARGN})

    set(_system_dlls
        advapi32.dll
        bcrypt.dll
        comdlg32.dll
        dbghelp.dll
        gdi32.dll
        imm32.dll
        iphlpapi.dll
        kernel32.dll
        ntdll.dll
        ole32.dll
        oleaut32.dll
        psapi.dll
        shell32.dll
        shlwapi.dll
        user32.dll
        userenv.dll
        uxtheme.dll
        version.dll
        winmm.dll
        ws2_32.dll)

    set(_allowed_prefixes
        "${VCPKG_INSTALLED_DIR}"
        "${VCPKG_INSTALLED_DIR}/x64-windows"
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin"
        "${CMAKE_SOURCE_DIR}")
    list(REMOVE_ITEM _allowed_prefixes "")
    list(REMOVE_DUPLICATES _allowed_prefixes)

    set(_resource_dirs)
    set(_data_dir "")
    foreach(_res data modules layouts)
        if(EXISTS "${CMAKE_SOURCE_DIR}/${_res}")
            if(_res STREQUAL "data")
                set(_data_dir "${CMAKE_SOURCE_DIR}/${_res}")
            else()
                list(APPEND _resource_dirs "${CMAKE_SOURCE_DIR}/${_res}")
            endif()
        endif()
    endforeach()

    set(_extra_files)
    if(EXISTS "${CMAKE_SOURCE_DIR}/init.lua")
        list(APPEND _extra_files "${CMAKE_SOURCE_DIR}/init.lua")
    endif()
    foreach(_root_extra IN ITEMS d3dcompiler_47.dll libGLESv2.dll libEGL.dll LICENSE)
        if(EXISTS "${CMAKE_SOURCE_DIR}/${_root_extra}")
            list(APPEND _extra_files "${CMAKE_SOURCE_DIR}/${_root_extra}")
        endif()
    endforeach()

    set(_hint_dirs
        "${VCPKG_INSTALLED_DIR}/x64-windows/bin"
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin")
    list(REMOVE_DUPLICATES _hint_dirs)

    # Debug: copy runtime DLLs next to the exe. Prefer vcpkg debug/bin first.
    set(_debug_copy_dlls
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin/bz2.dll"
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin/libcrypto-3-x64.dll"
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin/libssl-3-x64.dll"
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin/lua51.dll"
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin/physfs.dll"
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin/zip.dll"
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin/zlib1.dll"
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin/glew32d.dll")
    # Some ports ship debug DLLs without the 'd' suffix
    list(APPEND _debug_copy_dlls "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin/glew32.dll")

    # Also copy Boost debug runtime DLLs if present
    file(GLOB _boost_debug_dlls
        "${VCPKG_INSTALLED_DIR}/x64-windows/debug/bin/boost_*.dll")
    list(APPEND _debug_copy_dlls ${_boost_debug_dlls})

    set(_collect_script "${CMAKE_CURRENT_BINARY_DIR}/collect_runtime_deps.cmake")
    file(WRITE "${_collect_script}" [=[
if(NOT DEFINED CRD_TARGET_FILE)
  message(FATAL_ERROR "CRD_TARGET_FILE is required")
endif()
if(NOT DEFINED CRD_OUT_DIR)
  message(FATAL_ERROR "CRD_OUT_DIR is required")
endif()
if(NOT DEFINED CRD_DATA_DIR)
  set(CRD_DATA_DIR "")
endif()
if(NOT DEFINED CRD_KEEP_DATA_DIR)
  set(CRD_KEEP_DATA_DIR 0)
endif()
if(NOT DEFINED CRD_DEBUG_COPY_DLLS)
  set(CRD_DEBUG_COPY_DLLS "")
endif()

set(_target "${CRD_TARGET_FILE}")
set(_out_dir "${CRD_OUT_DIR}")
file(MAKE_DIRECTORY "${_out_dir}/lib")

# Debug mode: copy a known-good set of DLLs next to the executable.
if(CRD_KEEP_DATA_DIR)
  # Hardcoded direct copy for critical debug DLLs
  set(_vcpkg_debug_bin "C:/vcpkg-client/installed/x64-windows/debug/bin")
  foreach(_dll_name IN ITEMS glew32d.dll glew32.dll bz2d.dll libcrypto-3-x64.dll libssl-3-x64.dll lua51.dll physfs.dll zip.dll zlibd1.dll)
    if(EXISTS "${_vcpkg_debug_bin}/${_dll_name}")
      file(COPY "${_vcpkg_debug_bin}/${_dll_name}" DESTINATION "${_out_dir}")
    endif()
  endforeach()

  # Also copy from passed list
  foreach(_dll IN LISTS CRD_DEBUG_COPY_DLLS)
    if(EXISTS "${_dll}")
      file(COPY "${_dll}" DESTINATION "${_out_dir}")
    endif()
  endforeach()

  # Fallback: also try to pull common debug DLLs from hint dirs (vcpkg debug/bin)
  foreach(_hint_dir IN LISTS CRD_HINT_DIRS)
    foreach(_name IN ITEMS glew32d.dll glew32.dll libssl-3-x64.dll libcrypto-3-x64.dll bz2.dll zip.dll zlib1.dll lua51.dll physfs.dll)
      set(_full_path "${_hint_dir}/${_name}")
      if(EXISTS "${_full_path}")
        file(COPY "${_full_path}" DESTINATION "${_out_dir}")
      endif()
    endforeach()
  endforeach()
endif()

# Copy executable to dist root
if(EXISTS "${_target}")
  file(COPY "${_target}" DESTINATION "${_out_dir}")
endif()

set(_deps ${CRD_RUNTIME_DLLS})
if(COMMAND file AND EXISTS "${_target}")
  file(GET_RUNTIME_DEPENDENCIES
    EXECUTABLES "${_target}"
    RESOLVED_DEPENDENCIES_VAR _deps
    UNRESOLVED_DEPENDENCIES_VAR _unresolved
    CONFLICTING_DEPENDENCIES_PREFIX _conflicts
    DIRECTORIES ${CRD_HINT_DIRS})
  # If conflicts found, prefer vcpkg version over build dir copies
  foreach(_conflict_var IN LISTS _conflicts_FILENAMES)
    list(GET _conflicts_${_conflict_var} 0 _first_path)
    foreach(_cpath IN LISTS _conflicts_${_conflict_var})
      string(FIND "${_cpath}" "vcpkg" _vcpkg_idx)
      if(NOT _vcpkg_idx EQUAL -1)
        set(_first_path "${_cpath}")
        break()
      endif()
    endforeach()
    list(APPEND _deps "${_first_path}")
  endforeach()
elseif(WIN32)
  set(_deps ${CRD_RUNTIME_DLLS})
endif()

set(_system_lower)
foreach(_s IN LISTS CRD_SYSTEM_DLLS)
  string(TOLOWER "${_s}" _s_l)
  list(APPEND _system_lower "${_s_l}")
endforeach()

set(_filtered)
foreach(_dep IN LISTS _deps)
  if(NOT EXISTS "${_dep}")
    continue()
  endif()
  file(TO_CMAKE_PATH "${_dep}" _dep_norm)
  get_filename_component(_name "${_dep_norm}" NAME)
  string(TOLOWER "${_name}" _name_l)
  list(FIND _system_lower "${_name_l}" _sys_idx)
  if(NOT _sys_idx EQUAL -1)
    continue()
  endif()
  set(_ok FALSE)
  foreach(_prefix IN LISTS CRD_ALLOWED_PREFIXES)
    if(_prefix STREQUAL "")
      continue()
    endif()
    file(TO_CMAKE_PATH "${_prefix}" _prefix_norm)
    string(LENGTH "${_prefix_norm}" _pfx_len)
    string(SUBSTRING "${_dep_norm}" 0 ${_pfx_len} _front)
    if(_front STREQUAL "${_prefix_norm}")
      set(_ok TRUE)
      break()
    endif()
  endforeach()
  if(_ok)
    list(APPEND _filtered "${_dep_norm}")
  endif()
endforeach()

foreach(_dep IN LISTS _filtered)
  get_filename_component(_dep_name "${_dep}" NAME)
  string(TOLOWER "${_dep_name}" _dep_name_l)

  # Debug: keep DLLs next to the exe to avoid PATH picking up vcpkg debug/bin.
  if(CRD_KEEP_DATA_DIR)
    file(COPY "${_dep}" DESTINATION "${_out_dir}")
    continue()
  endif()

  # Release: keep clean layout under lib/, but glew32.dll and libcrypto must stay next to exe.
  if(_dep_name_l STREQUAL "glew32.dll" OR _dep_name_l STREQUAL "libcrypto-3-x64.dll")
    file(COPY "${_dep}" DESTINATION "${_out_dir}")
  else()
    file(COPY "${_dep}" DESTINATION "${_out_dir}/lib")
  endif()
endforeach()

# Ensure lua51.dll is copied if present in hint dirs (common vcpkg dependency)
if(NOT _filtered MATCHES "lua51\\.dll")
  find_file(_lua51 lua51.dll PATHS ${CRD_HINT_DIRS} NO_DEFAULT_PATH)
  if(_lua51)
    if(CRD_KEEP_DATA_DIR)
      file(COPY "${_lua51}" DESTINATION "${_out_dir}")
    else()
      file(COPY "${_lua51}" DESTINATION "${_out_dir}/lib")
    endif()
  endif()
endif()

# Ensure Boost DLLs are copied (they're delay-loaded in Release)
if(NOT CRD_KEEP_DATA_DIR)
  foreach(_boost_pattern IN ITEMS "boost_filesystem-*.dll" "boost_system-*.dll" "boost_atomic-*.dll")
    file(GLOB _boost_dlls "${CRD_VCPKG_BIN_DIR}/${_boost_pattern}")
    foreach(_boost_dll IN LISTS _boost_dlls)
      if(EXISTS "${_boost_dll}")
        file(COPY "${_boost_dll}" DESTINATION "${_out_dir}/lib")
      endif()
    endforeach()
  endforeach()
endif()

foreach(_res IN LISTS CRD_RESOURCE_DIRS)
  if(EXISTS "${_res}")
    file(COPY "${_res}" DESTINATION "${_out_dir}")
  endif()
endforeach()

# Hardcoded fallback: ensure layouts/ is always copied
if(NOT EXISTS "${_out_dir}/layouts")
  if(EXISTS "${CRD_LAYOUTS_DIR}")
    file(COPY "${CRD_LAYOUTS_DIR}" DESTINATION "${_out_dir}")
  endif()
endif()

foreach(_extra IN LISTS CRD_EXTRA_FILES)
  if(EXISTS "${_extra}")
    file(COPY "${_extra}" DESTINATION "${_out_dir}")
  endif()
endforeach()

if(EXISTS "${CRD_DATA_DIR}")
  # For testing builds: always ship uncompressed data/, no data.zip
  file(COPY "${CRD_DATA_DIR}" DESTINATION "${_out_dir}")
  file(REMOVE "${_out_dir}/data.zip")
endif()
]=])

    add_custom_command(TARGET ${TARGET} POST_BUILD
        COMMAND ${CMAKE_COMMAND}
            -DCRD_TARGET_FILE=$<TARGET_FILE:${TARGET}>
            -DCRD_RUNTIME_DLLS=$<TARGET_RUNTIME_DLLS:${TARGET}>
            "-DCRD_OUT_DIR=${OUT_DIR}"
            -DCRD_KEEP_DATA_DIR=$<IF:$<CONFIG:Debug>,1,0>
            -DCRD_SYSTEM_DLLS=${_system_dlls}
            -DCRD_ALLOWED_PREFIXES=${_allowed_prefixes}
            -DCRD_RESOURCE_DIRS=${_resource_dirs}
            -DCRD_EXTRA_FILES=${_extra_files}
            -DCRD_DEBUG_COPY_DLLS=${_debug_copy_dlls}
            -DCRD_HINT_DIRS=${_hint_dirs}
            -DCRD_DATA_DIR=${_data_dir}
            -DCRD_LAYOUTS_DIR=${CMAKE_SOURCE_DIR}/layouts
            -DCRD_VCPKG_BIN_DIR=${VCPKG_INSTALLED_DIR}/x64-windows/bin
            -DCRD_ZIP_PASSWORD=${CRD_ZIP_PASSWORD}
            -P "${_collect_script}"
        COMMAND_EXPAND_LISTS
        COMMENT "Collecting runtime dependencies for ${TARGET}"
        VERBATIM)

    # Only add custom install script for dynamic builds
    if(NOT USE_STATIC_LIBS)
        set(_install_code "set(_cfg \"$ENV{CMAKE_INSTALL_CONFIG_NAME}\")\n")
        string(APPEND _install_code "if(NOT _cfg AND DEFINED CMAKE_INSTALL_CONFIG_NAME)\n  set(_cfg \"\${CMAKE_INSTALL_CONFIG_NAME}\")\nendif()\n")
        string(APPEND _install_code "if(NOT _cfg AND DEFINED CMAKE_BUILD_TYPE)\n  set(_cfg \"\${CMAKE_BUILD_TYPE}\")\nendif()\n")
        string(APPEND _install_code "if(NOT _cfg)\n  set(_cfg \"Release\")\nendif()\n")
        string(APPEND _install_code "set(_out_dir \"\${CMAKE_INSTALL_PREFIX}\")\n")
        string(APPEND _install_code "set(_target_path \"\${CMAKE_INSTALL_PREFIX}/${TARGET}${CMAKE_EXECUTABLE_SUFFIX}\")\n")
        string(APPEND _install_code "file(MAKE_DIRECTORY \"\${_out_dir}/lib\")\n")
        string(APPEND _install_code "execute_process(COMMAND \"${CMAKE_COMMAND}\"\n  -DCRD_TARGET_FILE=\"\${_target_path}\"\n  -DCRD_RUNTIME_DLLS=\"\"\n  -DCRD_OUT_DIR=\"\${_out_dir}\"\n  -DCRD_SYSTEM_DLLS=${_system_dlls}\n  -DCRD_ALLOWED_PREFIXES=${_allowed_prefixes}\n  -DCRD_RESOURCE_DIRS=${_resource_dirs}\n  -DCRD_EXTRA_FILES=${_extra_files}\n  -DCRD_HINT_DIRS=${_hint_dirs}\n  -DCRD_DATA_DIR=${_data_dir}\n  -DCRD_LAYOUTS_DIR=${CMAKE_SOURCE_DIR}/layouts\n  -DCRD_ZIP_PASSWORD=${CRD_ZIP_PASSWORD}\n  -P \"${_collect_script}\")\n")
        install(CODE "${_install_code}")
    endif()
endfunction()

if(CMAKE_CONFIGURATION_TYPES)
    set(_deploy_root "${CMAKE_BINARY_DIR}/$<CONFIG>")
else()
    set(_deploy_root "${CMAKE_BINARY_DIR}")
endif()

# Install target: creates a clean distribution folder
# Usage: cmake --install out/build/x64-Release --prefix dist/RookhavenClient
install(TARGETS ${CLIENT_TARGET}
        RUNTIME DESTINATION "."
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib)

# Install runtime DLLs only for dynamic builds (not needed for static)
if(NOT USE_STATIC_LIBS)
    # Install runtime DLLs to lib/ (Release) - glew32.dll and libcrypto go to root
    install(FILES "${VCPKG_INSTALLED_DIR}/x64-windows/bin/glew32.dll" DESTINATION "." OPTIONAL)
    install(FILES "${VCPKG_INSTALLED_DIR}/x64-windows/bin/libcrypto-3-x64.dll" DESTINATION "." OPTIONAL)
    install(FILES "${VCPKG_INSTALLED_DIR}/x64-windows/bin/bz2.dll" DESTINATION "lib" OPTIONAL)
    install(FILES "${VCPKG_INSTALLED_DIR}/x64-windows/bin/libssl-3-x64.dll" DESTINATION "lib" OPTIONAL)
    install(FILES "${VCPKG_INSTALLED_DIR}/x64-windows/bin/lua51.dll" DESTINATION "lib" OPTIONAL)
    install(FILES "${VCPKG_INSTALLED_DIR}/x64-windows/bin/physfs.dll" DESTINATION "lib" OPTIONAL)
    install(FILES "${VCPKG_INSTALLED_DIR}/x64-windows/bin/zip.dll" DESTINATION "lib" OPTIONAL)
    install(FILES "${VCPKG_INSTALLED_DIR}/x64-windows/bin/zlib1.dll" DESTINATION "lib" OPTIONAL)

    # Install Boost DLLs to lib/
    file(GLOB _boost_release_dlls "${VCPKG_INSTALLED_DIR}/x64-windows/bin/boost_filesystem-*.dll"
                                  "${VCPKG_INSTALLED_DIR}/x64-windows/bin/boost_system-*.dll"
                                  "${VCPKG_INSTALLED_DIR}/x64-windows/bin/boost_atomic-*.dll")
    foreach(_boost_dll IN LISTS _boost_release_dlls)
        install(FILES "${_boost_dll}" DESTINATION "lib" OPTIONAL)
    endforeach()
endif()

# Install resource directories
# For static (Release) builds: package data/ and init.lua into data.zip
# For dynamic (Debug) builds: install uncompressed data/ and init.lua
if(USE_STATIC_LIBS)
    # Create data.zip during install containing init.lua and data/ folder
    # This protects Lua sources from end-users
    install(CODE "
        message(STATUS \"Creating data.zip for Release distribution...\")
        set(_data_zip_path \"\${CMAKE_INSTALL_PREFIX}/data.zip\")
        set(_source_dir \"${CMAKE_SOURCE_DIR}\")
        
        # Remove old data.zip if exists
        if(EXISTS \"\${_data_zip_path}\")
            file(REMOVE \"\${_data_zip_path}\")
        endif()
        
        # Use CMake's tar command to create a zip archive
        # We need to change to source dir to get correct relative paths
        execute_process(
            COMMAND \${CMAKE_COMMAND} -E tar cf \"\${_data_zip_path}\" --format=zip -- init.lua data
            WORKING_DIRECTORY \"\${_source_dir}\"
            RESULT_VARIABLE _zip_result
        )
        
        if(NOT _zip_result EQUAL 0)
            message(FATAL_ERROR \"Failed to create data.zip\")
        endif()
        
        message(STATUS \"Created data.zip successfully\")
    ")
    # Don't install uncompressed data/ or init.lua for Release
else()
    # Debug build: install uncompressed
    install(DIRECTORY "${CMAKE_SOURCE_DIR}/data" DESTINATION ".")
    install(FILES "${CMAKE_SOURCE_DIR}/init.lua" DESTINATION ".")
endif()

install(DIRECTORY "${CMAKE_SOURCE_DIR}/modules" DESTINATION "."
        PATTERN "game_bot" EXCLUDE)  # Exclude bot module from distribution
install(DIRECTORY "${CMAKE_SOURCE_DIR}/layouts" DESTINATION ".")

# Install extra files (init.lua is already handled above for Debug, and in data.zip for Release)
if(EXISTS "${CMAKE_SOURCE_DIR}/d3dcompiler_47.dll")
    install(FILES "${CMAKE_SOURCE_DIR}/d3dcompiler_47.dll" DESTINATION ".")
endif()
if(EXISTS "${CMAKE_SOURCE_DIR}/libEGL.dll")
    install(FILES "${CMAKE_SOURCE_DIR}/libEGL.dll" DESTINATION ".")
endif()
if(EXISTS "${CMAKE_SOURCE_DIR}/libGLESv2.dll")
    install(FILES "${CMAKE_SOURCE_DIR}/libGLESv2.dll" DESTINATION ".")
endif()
if(EXISTS "${CMAKE_SOURCE_DIR}/LICENSE")
    install(FILES "${CMAKE_SOURCE_DIR}/LICENSE" DESTINATION ".")
endif()

collect_runtime_deps(${CLIENT_TARGET} "${_deploy_root}" ZIP_DATA_PASSWORD "${RUNTIME_DATA_ZIP_PASSWORD}")
