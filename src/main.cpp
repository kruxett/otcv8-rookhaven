/*
 * Copyright (c) 2010-2017 OTClient <https://github.com/edubart/otclient>
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

#include <framework/core/application.h>
#include <framework/core/resourcemanager.h>
#include <framework/core/eventdispatcher.h>
#include <framework/luaengine/luainterface.h>
#include <framework/http/http.h>
#include <framework/platform/crashhandler.h>
#include <framework/platform/platformwindow.h>
#include <client/client.h>

#ifdef WIN32
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x0602  // Windows 8 for AddDllDirectory
#include <windows.h>
#include <filesystem>

static void setupDllSearchPath() {
    wchar_t exePath[MAX_PATH] = {0};
    if(GetModuleFileNameW(nullptr, exePath, MAX_PATH) == 0)
        return;

    std::filesystem::path exeDir = std::filesystem::path(exePath).parent_path();
    std::filesystem::path libDir = exeDir / L"lib";

    // Modern Windows 8+ method (preferred and secure)
    // This tells Windows to look in our lib/ directory for DLLs.
    // If this fails, fall back to PATH modification below.
    if(SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_DEFAULT_DIRS | LOAD_LIBRARY_SEARCH_USER_DIRS)) {
        AddDllDirectory(libDir.c_str());
    }

    // Fallback: Also add to PATH for older methods or LoadLibrary calls
    std::wstring lib = libDir.wstring();
    wchar_t currentPath[32768] = {0};
    DWORD len = GetEnvironmentVariableW(L"PATH", currentPath, 32768);
    std::wstring newPath;
    if(len > 0 && len < 32768)
        newPath = lib + L";" + std::wstring(currentPath, len);
    else
        newPath = lib;
    SetEnvironmentVariableW(L"PATH", newPath.c_str());

    // Explicitly preload lua51.dll from lib directory
    std::filesystem::path luaPath = libDir / L"lua51.dll";
    if(std::filesystem::exists(luaPath))
        LoadLibraryW(luaPath.c_str());
}
#endif

int main(int argc, const char* argv[]) {
    std::vector<std::string> args(argv, argv + argc);

#ifdef WIN32
    setupDllSearchPath();
#endif

#ifdef CRASH_HANDLER
    installCrashHandler();
#endif

    // initialize resources
    g_resources.init(argv[0]);
    std::string compactName = g_resources.getCompactName();
    g_logger.setLogFile(compactName + ".log");

    // setup application name and version
    g_app.setName("OTClientV8");
    g_app.setCompactName(compactName);
    g_app.setVersion("3.2");

#ifdef WITH_ENCRYPTION
    if (std::find(args.begin(), args.end(), "--encrypt") != args.end()) {
        g_lua.init();
        g_resources.encrypt(args.size() >= 3 ? args[2] : "");
        std::cout << "Encryption complete" << std::endl;
#ifdef WIN32
        MessageBoxA(NULL, "Encryption complete", "Success", 0);
#endif
        return 0;
    }
#endif

    if (g_resources.launchCorrect(g_app.getName(), g_app.getCompactName())) {
        return 0; // started other executable
    }

    // initialize application framework and otclient
    g_app.init(args);
    g_client.init(args);

#ifdef DEFAULT_SERVER_ENDPOINT
    // Expose the baked-in default server endpoint to Lua before init.lua runs
    g_lua.pushCString(DEFAULT_SERVER_ENDPOINT);
    g_lua.setGlobal("DEFAULT_SERVER_ENDPOINT");
#endif

    g_http.init();

    bool testMode = std::find(args.begin(), args.end(), "--test") != args.end();
    if (testMode) {
        g_logger.setTestingMode();    
    }

    // find script init.lua and run it
    g_resources.setupWriteDir(g_app.getName(), g_app.getCompactName());
    g_resources.setup();

    auto runInit = []() {
        return g_lua.safeRunScript("init.lua");
    };

    bool initOk = runInit();

    if (!initOk) {
        g_logger.warning("Unable to run script init.lua, retrying without user data overrides.");
        if (g_resources.setup(true)) {
            initOk = runInit();
        }
    }

    if (!initOk) {
        if (g_resources.isLoadedFromArchive() && !g_resources.isLoadedFromMemory() &&
            g_resources.loadDataFromSelf(true)) {
            g_logger.error("Unable to run script init.lua! Trying to run version from memory.");
            if (!runInit()) {
                g_resources.deleteFile("data.zip"); // remove incorrect data.zip
                g_logger.fatal("Unable to run script init.lua from binary file!\nTry to run client again.");
            }
        } else {
            g_logger.fatal("Unable to run script init.lua!");
        }
    }

    if (testMode) {
        if (!g_lua.safeRunScript("test.lua")) {
            g_logger.fatal("Can't run test.lua");
        }
    }

#ifdef WIN32
    // support for progdn proxy system, if you don't have this dll nothing will happen
    // however, it is highly recommended to use otcv8 proxy system
    LoadLibraryA("progdn32.dll");
#endif

    // the run application main loop
    g_app.run();

#ifdef CRASH_HANDLER
    uninstallCrashHandler();
#endif

    // unload modules
    g_app.deinit();

    // terminate everything and free memory
    g_http.terminate();
    g_client.terminate();
    g_app.terminate();
    return 0;
}

#ifdef ANDROID
#include <framework/platform/androidwindow.h>

android_app* g_androidState = nullptr;
void android_main(struct android_app* state)
{
    g_mainThreadId = g_dispatcherThreadId = g_graphicsThreadId = std::this_thread::get_id();
    g_androidState = state;

    state->userData = nullptr;
    state->onAppCmd = +[](android_app* app, int32_t cmd) -> void {
       return g_androidWindow.handleCmd(cmd);
    };
    state->onInputEvent = +[](android_app* app, AInputEvent* event) -> int32_t {
        return g_androidWindow.handleInput(event);
    };
    state->activity->callbacks->onNativeWindowResized = +[](ANativeActivity* activity, ANativeWindow* window) -> void {
        g_graphicsDispatcher.scheduleEventEx("updateWindowSize", [] {
            g_androidWindow.updateSize();
        }, 500);
    };
    state->activity->callbacks->onContentRectChanged = +[](ANativeActivity* activity, const ARect* rect) -> void {
        g_graphicsDispatcher.scheduleEventEx("updateWindowSize", [] {
            g_androidWindow.updateSize();
        }, 500);
    };

    bool terminated = false;
    g_window.setOnClose([&] {
        terminated = true;
    });
    while(!g_window.isVisible() && !terminated)
        g_window.poll(); // init window
    // run app
    const char* args[] = { "otclientv8.apk" };
    main(1, args);
    std::exit(0); // required!
}
#endif
