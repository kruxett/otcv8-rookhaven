# FindOpenSSL.cmake - Windows + vcpkg (supports static and dynamic)

if(USE_STATIC_LIBS)
    set(OPENSSL_INCLUDE_DIR "C:/vcpkg/installed/x64-windows-static/include")
    set(OPENSSL_CRYPTO_LIBRARY "C:/vcpkg/installed/x64-windows-static/lib/libcrypto.lib")
    set(OPENSSL_SSL_LIBRARY "C:/vcpkg/installed/x64-windows-static/lib/libssl.lib")
else()
    set(OPENSSL_INCLUDE_DIR "C:/vcpkg/installed/x64-windows/include")
    set(OPENSSL_CRYPTO_LIBRARY "C:/vcpkg/installed/x64-windows/lib/libcrypto.lib")
    set(OPENSSL_SSL_LIBRARY "C:/vcpkg/installed/x64-windows/lib/libssl.lib")
endif()

set(OPENSSL_LIBRARIES
    ${OPENSSL_SSL_LIBRARY}
    ${OPENSSL_CRYPTO_LIBRARY}
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(OpenSSL DEFAULT_MSG
    OPENSSL_LIBRARIES
    OPENSSL_INCLUDE_DIR
)

mark_as_advanced(
    OPENSSL_INCLUDE_DIR
    OPENSSL_SSL_LIBRARY
    OPENSSL_CRYPTO_LIBRARY
    OPENSSL_LIBRARIES
)