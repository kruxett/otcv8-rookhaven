//
// Compatibility header: io_service.hpp -> io_context.hpp
// This file provides backward compatibility for code using the old io_service API
//

#ifndef BOOST_ASIO_IO_SERVICE_HPP_COMPAT
#define BOOST_ASIO_IO_SERVICE_HPP_COMPAT

// Include the new API
#include <boost/asio/io_context.hpp>

namespace boost {
namespace asio {

// io_service is now an alias for io_context
typedef io_context io_service;

} // namespace asio
} // namespace boost

#endif // BOOST_ASIO_IO_SERVICE_HPP_COMPAT
