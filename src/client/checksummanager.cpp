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
#include "rookhaven_resources.h"
#include <framework/util/crypt.h>
#include <framework/core/resourcemanager.h>
#include <sstream>
#include <iomanip>
#include <filesystem>
#include <iostream>

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

std::string ChecksumManager::generateLoginProof(uint32_t timestamp, uint8_t random)
{
    const std::string material = std::string("RH2|") + RookhavenResources::fingerprint + "|" +
        g_resources.selfChecksum() + "|" + std::to_string(timestamp) + "|" + std::to_string(random);
    return g_crypt.sha256Encode(material, false);
}

std::string ChecksumManager::generateChecksumResponse(const std::string& challengeId, const std::vector<std::string>& files)
{
    // Build JSON response: {"_challengeId":"123","file1":"checksum1",...}
    std::ostringstream oss;
    oss << "{";
    oss << "\"_challengeId\":\"" << challengeId << "\",";
    oss << "\"_timestamp\":\"" << time(nullptr) << "\"";
    
    for (const auto& filepath : files) {
        std::string checksum = g_resources.fileChecksumUncached(filepath);
        oss << ",\"" << filepath << "\":\"" << checksum << "\"";
    }
    
    oss << "}";
    return oss.str();
}

bool ChecksumManager::verifyDataZipExists()
{
    // Validate the installed archive beside the executable, independent of cwd.
    return g_resources.dataArchiveExists();
}
