//
// Local compatibility shim: boost/asio/io_service.hpp
// Provides io_service alias for legacy code with Boost 1.90+
//
#ifndef BOOST_ASIO_IO_SERVICE_HPP
#define BOOST_ASIO_IO_SERVICE_HPP

#if defined(_MSC_VER) && (_MSC_VER >= 1200)
#  pragma once
#endif

#include <boost/asio/io_context.hpp>

namespace boost {
namespace asio {

using io_service = io_context;

} // namespace asio
} // namespace boost

#endif // BOOST_ASIO_IO_SERVICE_HPP
