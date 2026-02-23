/*
 * Copyright (c) 2010-2022 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "checksummanager.h"
#include <framework/core/resourcemanager.h>
#include <sstream>
#include <iomanip>

std::vector<std::string> ChecksumManager::getCriticalFiles()
{
    return {
        "/modules/corelib/corelib.otmod",
        "/modules/corelib/util.lua",
        "/modules/corelib/globals.lua",
        "/modules/gamelib/gamelib.otmod",
        "/modules/gamelib/game.lua",
        "/modules/gamelib/protocolgame.lua",
        "/modules/game_protocol/protocol.lua",
        "/modules/game_features/features.lua",
    };
}

uint32_t ChecksumManager::hashString(const std::string& input)
{
    uint32_t h = 0;
    for (unsigned char c : input) {
        h = (h * 33u + c) & 0xFFFFFFFFu;
    }
    return h;
}

std::string ChecksumManager::generateLoginChecksum()
{
    std::string combined;
    
    // Get checksums for all critical files from actual client files
    auto criticalFiles = getCriticalFiles();
    for (const auto& filepath : criticalFiles) {
        std::string checksum = g_resources.fileChecksum(filepath);
        combined += checksum + "|";
    }
    
    // Skip binary checksum - it changes every build
    // std::string binaryChecksum = g_resources.selfChecksum();
    // if (!binaryChecksum.empty()) {
    //     combined += binaryChecksum;
    // }
    
    // Hash the combined string
    uint32_t hash = hashString(combined);
    
    // Format as CS1:XXXXXXXX
    std::ostringstream oss;
    oss << "CS1:" << std::hex << std::setfill('0') << std::setw(8) << hash;
    
    return oss.str();
}

std::string ChecksumManager::generateChecksumResponse(const std::string& challengeId, const std::vector<std::string>& files)
{
    // Build JSON response: {"_challengeId":"123","file1":"checksum1",...}
    std::ostringstream oss;
    oss << "{";
    oss << "\"_challengeId\":\"" << challengeId << "\",";
    oss << "\"_timestamp\":\"" << time(nullptr) << "\"";
    
    for (const auto& filepath : files) {
        std::string checksum = g_resources.fileChecksum(filepath);
        oss << ",\"" << filepath << "\":\"" << checksum << "\"";
    }
    
    oss << "}";
    return oss.str();
}
