#ifndef DISCORDRPC_H
#define DISCORDRPC_H

#include <string>

class DiscordRPCManager
{
public:
    bool initialize(const std::string& applicationId);
    void shutdown();

    bool isInitialized() const { return m_initialized; }
    bool isAvailable() const { return m_available; }
    std::string getLastError() const { return m_lastError; }

    void runCallbacks();
    void clearPresence();
    void setPresence(const std::string& state,
                     const std::string& details,
                     const std::string& largeImageKey,
                     const std::string& largeImageText,
                     const std::string& smallImageKey,
                     const std::string& smallImageText);

private:
    void setError(const std::string& error) { m_lastError = error; }

    bool m_initialized = false;
    bool m_available = false;
    std::string m_lastError;
    std::string m_applicationId;

#ifdef WIN32
    struct PlatformData;
    PlatformData* m_platformData = nullptr;
#endif
};

extern DiscordRPCManager g_discord;

#endif
