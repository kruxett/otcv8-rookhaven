#include "discordrpc.h"

#include <framework/core/logger.h>

#ifdef WIN32
#include <windows.h>
#include <cstring>
#include <cstdint>
#include <string>

namespace {
std::string getExecutableDir()
{
    char modulePath[MAX_PATH] = { 0 };
    if (GetModuleFileNameA(nullptr, modulePath, MAX_PATH) == 0)
        return "";

    std::string path(modulePath);
    const auto pos = path.find_last_of("\\/");
    if (pos == std::string::npos)
        return "";
    return path.substr(0, pos);
}

HMODULE loadDiscordLibrary(std::string& loadedFrom)
{
    HMODULE lib = LoadLibraryA("discord-rpc.dll");
    if (lib) {
        loadedFrom = "discord-rpc.dll";
        return lib;
    }

    const std::string exeDir = getExecutableDir();
    if (!exeDir.empty()) {
        const std::string inExeDir = exeDir + "\\discord-rpc.dll";
        lib = LoadLibraryA(inExeDir.c_str());
        if (lib) {
            loadedFrom = inExeDir;
            return lib;
        }

        const std::string inLibDir = exeDir + "\\lib\\discord-rpc.dll";
        lib = LoadLibraryA(inLibDir.c_str());
        if (lib) {
            loadedFrom = inLibDir;
            return lib;
        }
    }

    return nullptr;
}
}

struct DiscordUser {
    const char* userId;
    const char* username;
    const char* discriminator;
    const char* avatar;
};

struct DiscordRichPresence {
    const char* state;
    const char* details;
    int64_t startTimestamp;
    int64_t endTimestamp;
    const char* largeImageKey;
    const char* largeImageText;
    const char* smallImageKey;
    const char* smallImageText;
    const char* partyId;
    int partySize;
    int partyMax;
    const char* matchSecret;
    const char* joinSecret;
    const char* spectateSecret;
    int8_t instance;
};

struct DiscordEventHandlers {
    void (*ready)(const DiscordUser* request);
    void (*disconnected)(int errorCode, const char* message);
    void (*errored)(int errorCode, const char* message);
    void (*joinGame)(const char* joinSecret);
    void (*spectateGame)(const char* spectateSecret);
    void (*joinRequest)(const DiscordUser* request);
};

using Discord_InitializeFn = void(__cdecl*)(const char*, DiscordEventHandlers*, int, const char*);
using Discord_ShutdownFn = void(__cdecl*)();
using Discord_RunCallbacksFn = void(__cdecl*)();
using Discord_UpdatePresenceFn = void(__cdecl*)(const DiscordRichPresence*);
using Discord_ClearPresenceFn = void(__cdecl*)();

struct DiscordRPCManager::PlatformData {
    HMODULE library = nullptr;
    Discord_InitializeFn initialize = nullptr;
    Discord_ShutdownFn shutdown = nullptr;
    Discord_RunCallbacksFn runCallbacks = nullptr;
    Discord_UpdatePresenceFn updatePresence = nullptr;
    Discord_ClearPresenceFn clearPresence = nullptr;
};
#endif

DiscordRPCManager g_discord;

bool DiscordRPCManager::initialize(const std::string& applicationId)
{
#ifdef WIN32
    if (m_initialized && m_applicationId == applicationId)
        return true;

    shutdown();

    if (applicationId.empty()) {
        m_available = false;
        setError("Discord RPC app id is empty");
        return false;
    }

    auto* data = new PlatformData();
    std::string loadedFrom;
    data->library = loadDiscordLibrary(loadedFrom);
    if (!data->library) {
        setError("Unable to load discord-rpc.dll (tried executable path and executable path/lib)");
        delete data;
        m_available = false;
        return false;
    }

    data->initialize = reinterpret_cast<Discord_InitializeFn>(GetProcAddress(data->library, "Discord_Initialize"));
    data->shutdown = reinterpret_cast<Discord_ShutdownFn>(GetProcAddress(data->library, "Discord_Shutdown"));
    data->runCallbacks = reinterpret_cast<Discord_RunCallbacksFn>(GetProcAddress(data->library, "Discord_RunCallbacks"));
    data->updatePresence = reinterpret_cast<Discord_UpdatePresenceFn>(GetProcAddress(data->library, "Discord_UpdatePresence"));
    data->clearPresence = reinterpret_cast<Discord_ClearPresenceFn>(GetProcAddress(data->library, "Discord_ClearPresence"));

    if (!data->initialize || !data->shutdown || !data->runCallbacks || !data->updatePresence || !data->clearPresence) {
        setError("discord-rpc.dll is missing required symbols");
        FreeLibrary(data->library);
        delete data;
        m_available = false;
        return false;
    }

    DiscordEventHandlers handlers;
    std::memset(&handlers, 0, sizeof(handlers));

    data->initialize(applicationId.c_str(), &handlers, 1, nullptr);

    m_platformData = data;
    m_applicationId = applicationId;
    m_initialized = true;
    m_available = true;
    m_lastError.clear();

    g_logger.info("Discord RPC initialized (appId=" + applicationId + ", dll=" + loadedFrom + ")");
    return true;
#else
    (void)applicationId;
    m_available = false;
    setError("Discord RPC is currently implemented for Windows builds only");
    return false;
#endif
}

void DiscordRPCManager::shutdown()
{
#ifdef WIN32
    if (!m_platformData)
        return;

    if (m_platformData->shutdown)
        m_platformData->shutdown();

    if (m_platformData->library)
        FreeLibrary(m_platformData->library);

    delete m_platformData;
    m_platformData = nullptr;
#endif
    m_initialized = false;
    m_available = false;
}

void DiscordRPCManager::runCallbacks()
{
#ifdef WIN32
    if (!m_initialized || !m_platformData || !m_platformData->runCallbacks)
        return;
    m_platformData->runCallbacks();
#endif
}

void DiscordRPCManager::clearPresence()
{
#ifdef WIN32
    if (!m_initialized || !m_platformData || !m_platformData->clearPresence)
        return;
    m_platformData->clearPresence();
#endif
}

void DiscordRPCManager::setPresence(const std::string& state,
                                    const std::string& details,
                                    const std::string& largeImageKey,
                                    const std::string& largeImageText,
                                    const std::string& smallImageKey,
                                    const std::string& smallImageText)
{
#ifdef WIN32
    if (!m_initialized || !m_platformData || !m_platformData->updatePresence)
        return;

    DiscordRichPresence presence;
    std::memset(&presence, 0, sizeof(presence));

    presence.state = state.empty() ? nullptr : state.c_str();
    presence.details = details.empty() ? nullptr : details.c_str();
    presence.largeImageKey = largeImageKey.empty() ? nullptr : largeImageKey.c_str();
    presence.largeImageText = largeImageText.empty() ? nullptr : largeImageText.c_str();
    presence.smallImageKey = smallImageKey.empty() ? nullptr : smallImageKey.c_str();
    presence.smallImageText = smallImageText.empty() ? nullptr : smallImageText.c_str();

    m_platformData->updatePresence(&presence);
#else
    (void)state;
    (void)details;
    (void)largeImageKey;
    (void)largeImageText;
    (void)smallImageKey;
    (void)smallImageText;
#endif
}
