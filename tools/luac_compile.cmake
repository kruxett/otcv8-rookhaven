if(NOT DEFINED ROOT_DIR)
  message(FATAL_ERROR "ROOT_DIR is required")
endif()

if(NOT DEFINED LUAC_EXECUTABLE OR LUAC_EXECUTABLE STREQUAL "")
  find_program(LUAC_EXECUTABLE NAMES luajit luajit.exe luac luac.exe)
endif()

if(NOT LUAC_EXECUTABLE)
  message(FATAL_ERROR "luac/luajit executable not found. Set LUAC_EXECUTABLE or ensure luajit/luac is in PATH.")
endif()

# Detect if we're using LuaJIT or standard Lua
get_filename_component(_luac_name "${LUAC_EXECUTABLE}" NAME_WE)
string(TOLOWER "${_luac_name}" _luac_name_lower)
set(_is_luajit FALSE)
set(_luajit_lua_path "")
if(_luac_name_lower MATCHES "luajit")
  set(_is_luajit TRUE)
  message(STATUS "Using LuaJIT bytecode compiler")
  
  # Set up LUA_PATH for LuaJIT to find jit.* modules
  get_filename_component(_luajit_dir "${LUAC_EXECUTABLE}" DIRECTORY)
  get_filename_component(_luajit_root "${_luajit_dir}" DIRECTORY)
  set(_luajit_lua_path "${_luajit_root}/lua/?.lua;${_luajit_root}/lua/?/init.lua;;")
else()
  message(STATUS "Using standard Lua bytecode compiler")
endif()

set(_lua_dirs
  "${ROOT_DIR}/modules"
  "${ROOT_DIR}/data")

set(_lua_files)
foreach(_dir IN LISTS _lua_dirs)
  if(EXISTS "${_dir}")
    file(GLOB_RECURSE _dir_files "${_dir}/*.lua")
    list(APPEND _lua_files ${_dir_files})
  endif()
endforeach()

if(EXISTS "${ROOT_DIR}/init.lua")
  list(APPEND _lua_files "${ROOT_DIR}/init.lua")
endif()

foreach(_lua_file IN LISTS _lua_files)
  string(REGEX REPLACE "\\.lua$" ".luac" _luac_file "${_lua_file}")
  
  # LuaJIT uses -b flag for bytecode compilation
  if(_is_luajit)
    # Set LUA_PATH environment variable for LuaJIT
    set(ENV{LUA_PATH} "${_luajit_lua_path}")
    execute_process(
      COMMAND "${LUAC_EXECUTABLE}" -b "${_lua_file}" "${_luac_file}"
      RESULT_VARIABLE _luac_result
      OUTPUT_VARIABLE _luac_out
      ERROR_VARIABLE _luac_err)
  else()
    execute_process(
      COMMAND "${LUAC_EXECUTABLE}" -o "${_luac_file}" "${_lua_file}"
      RESULT_VARIABLE _luac_result
      OUTPUT_VARIABLE _luac_out
      ERROR_VARIABLE _luac_err)
  endif()
  
  if(NOT _luac_result EQUAL 0)
    message(FATAL_ERROR "Bytecode compilation failed for ${_lua_file}: ${_luac_err}")
  endif()
  file(REMOVE "${_lua_file}")
endforeach()

if(EXISTS "${ROOT_DIR}/data.zip")
  file(REMOVE "${ROOT_DIR}/data.zip")
endif()

set(_init_entry "init.lua")
if(EXISTS "${ROOT_DIR}/init.luac")
  set(_init_entry "init.luac")
endif()

execute_process(
  COMMAND "${CMAKE_COMMAND}" -E tar cf "${ROOT_DIR}/data.zip" --format=zip -- ${_init_entry} data modules layouts
  WORKING_DIRECTORY "${ROOT_DIR}"
  RESULT_VARIABLE _zip_result)

if(NOT _zip_result EQUAL 0)
  message(FATAL_ERROR "Failed to create data.zip in ${ROOT_DIR}")
endif()
