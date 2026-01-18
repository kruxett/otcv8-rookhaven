#include "net.h"
#include <boost/lexical_cast.hpp>
#include <boost/algorithm/string.hpp>
#include <boost/asio/ip/address_v4.hpp>
#include <boost/asio/ip/address.hpp>
#include <boost/system/error_code.hpp>

namespace stdext {

    std::string ip_to_string(uint32 ip)
    {
        ip = boost::asio::detail::socket_ops::network_to_host_long(ip);
        boost::asio::ip::address_v4 address_v4(ip);
        return address_v4.to_string();
    }

    uint32 string_to_ip(const std::string& string)
    {
        boost::system::error_code ec;
        auto address = boost::asio::ip::make_address_v4(string, ec);
        if (ec) {
            return 0; // eller kasta exception/logga om du vill
        }

        return boost::asio::detail::socket_ops::host_to_network_long(address.to_uint());
    }

    std::vector<uint32> listSubnetAddresses(uint32 address, uint8 mask)
    {
        std::vector<uint32> list;
        if (mask < 32) {
            uint32 bitmask = (0xFFFFFFFFu >> mask);
            for (uint32 i = 0; i <= bitmask; ++i) {
                uint32 ip = boost::asio::detail::socket_ops::host_to_network_long(
                    (boost::asio::detail::socket_ops::network_to_host_long(address) & (~bitmask)) | i
                );
                if ((ip >> 24) != 0 && (ip >> 24) != 0xFF)
                    list.push_back(ip);
            }
        }
        else {
            list.push_back(address);
        }

        return list;
    }

}