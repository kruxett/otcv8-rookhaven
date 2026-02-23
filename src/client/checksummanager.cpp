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
    
    // Get ALL file checksums from data.zip directly (bypass cache)
    auto allChecksums = g_resources.filesChecksums();
    
    // Get checksums for critical files from the uncached map
    auto criticalFiles = getCriticalFiles();
    for (const auto& filepath : criticalFiles) {
        auto it = allChecksums.find(filepath);
        if (it != allChecksums.end()) {
            combined += it->second + "|";
        }
    }
    
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

std::string ChecksumManager::getDataZipChecksum()
{
    // Check if data.zip exists and compute its checksum
    // This prevents cache bypass - file must exist on disk
    std::ifstream file("data.zip", std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        return ""; // data.zip not found
    }
    
    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);
    
    std::string buffer(size, 0);
    if (!file.read(&buffer[0], size)) {
        return "";
    }
    
    // Compute CRC32 of data.zip file
    return g_crypt.crc32(buffer, false);
}
