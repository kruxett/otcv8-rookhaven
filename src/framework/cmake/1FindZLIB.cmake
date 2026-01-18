# Try to find the ZLIB library
#  ZLIB_FOUND - system has ZLIB
#  ZLIB_INCLUDE_DIR - the ZLIB include directory
#  ZLIB_LIBRARY - the ZLIB library

find_path(ZLIB_INCLUDE_DIR NAMES zlib.h PATH_SUFFIXES include)

find_library(ZLIB_LIBRARY
    NAMES zlib zlib1 zlibstatic
    PATH_SUFFIXES lib
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ZLIB DEFAULT_MSG ZLIB_LIBRARY ZLIB_INCLUDE_DIR)

mark_as_advanced(ZLIB_LIBRARY ZLIB_INCLUDE_DIR)