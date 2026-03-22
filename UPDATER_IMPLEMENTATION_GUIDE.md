# Rookhaven Updater — Implementation Guide

**Status:** Prepared, not yet implemented  
**Companion doc:** `UPDATER_SYSTEM_DESIGN.md` (architecture overview, Railway deploy goals)  
**Last updated:** March 2026

This document is a step-by-step execution guide. Architecture rationale lives in `UPDATER_SYSTEM_DESIGN.md`. This guide only contains the exact code to write, files to touch, and the order to do it in.

---

## Table of Contents

1. [How the system works end-to-end](#1-how-it-works-end-to-end)
2. [Phase 1 — Updater API (Node.js on VPS)](#2-phase-1--updater-api-nodejs-on-vps)
3. [Phase 2 — Enable updater in client (init.lua)](#3-phase-2--enable-updater-in-clientinitlua)
4. [Phase 3 — Fix checksum .lua/.luac compatibility](#4-phase-3--fix-checksum-lualuac-compatibility)
5. [Phase 4 — First release artifacts](#5-phase-4--first-release-artifacts)
6. [Phase 5 — Release checklist (for every future release)](#6-phase-5--release-checklist)
7. [Phase 6 — Test scenarios](#7-phase-6--test-scenarios)
8. [Troubleshooting reference](#8-troubleshooting-reference)

---

## 1. How It Works End-to-End

```
[Client launches]
       │
       ▼
init.lua checks:
  - Services.updater is set (non-empty URL)?
  - g_resources.isLoadedFromArchive() == true?  ← requires data.zip distribution
  - updater module exists?
       │ all yes
       ▼
updater.lua:  HTTP POST to Services.updater URL
  sends: { version, build, os, platform, args }
       │
       ▼
Node.js API:
  - compares client version to manifest currentVersion
  - if up to date → responds { message: "Client is up to date" }
  - if outdated  → responds { files: {path: sha256, ...}, url: "https://github.com/.../download/vX.Y/", binary: {...} }
       │
       ▼
updater.lua:
  - downloads each file from url + filename
  - verifies checksum
  - writes to disk
  - if binary update: replaces exe, restarts
  - if Lua-only:  relaunches (or just continues)
       │
       ▼
[Game loads normally]
```

**Critical requirement:** The client must be running from `data.zip` (built with `USE_STATIC_LIBS=ON`, then `cmake --install`). The guard in `init.lua` will skip the updater if files are loaded loose from disk (i.e. debug/dev mode). This is intentional.

---

## 2. Phase 1 — Updater API (Node.js on VPS)

### 2.1 Create the API directory

On your VPS (or locally then deploy), create a folder `rookhaven-updater/`:

```
rookhaven-updater/
  updater-api.js
  package.json
  manifest.json         ← updated each release, read by the API at runtime
  .gitignore
```

### 2.2 `package.json`

```json
{
  "name": "rookhaven-updater-api",
  "version": "1.0.0",
  "description": "Auto-updater API for Rookhaven OT client",
  "main": "updater-api.js",
  "scripts": {
    "start": "node updater-api.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

### 2.3 `updater-api.js`

```javascript
'use strict';
const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());

// Manifest is read from disk on every request so you can update it
// without restarting the process (just overwrite manifest.json).
function loadManifest() {
  const manifestPath = path.join(__dirname, 'manifest.json');
  try {
    return JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  } catch (e) {
    console.error('[updater] Failed to load manifest.json:', e.message);
    return null;
  }
}

// Health check — used by monitoring and as a smoke-test before release
app.get('/health', (req, res) => {
  const manifest = loadManifest();
  res.json({
    status: 'ok',
    uptime: Math.floor(process.uptime()),
    release_version: manifest?.release?.currentVersion ?? null,
    dev_version: manifest?.dev?.currentVersion ?? null,
    timestamp: new Date().toISOString()
  });
});

// Get published versions (for external status pages if needed)
app.get('/api/versions', (req, res) => {
  const manifest = loadManifest();
  if (!manifest) return res.status(500).json({ error: 'Manifest unavailable' });
  res.json({
    release: manifest.release?.currentVersion,
    dev: manifest.dev?.currentVersion
  });
});

// Main updater endpoint — client POSTs here on every launch
app.post('/api/updater', (req, res) => {
  const { version, build, os, platform, args } = req.body;

  if (typeof version !== 'number') {
    return res.status(400).json({ error: 'Missing or invalid version field' });
  }

  const manifest = loadManifest();
  if (!manifest) {
    return res.status(500).json({ error: 'Server manifest unavailable, try again later' });
  }

  // DEV detection: version >= 10000 OR args.dev === true
  const isDev = (args?.dev === true) || (version >= 10000);
  const channel = isDev ? 'dev' : 'release';
  const channelManifest = manifest[channel];

  if (!channelManifest) {
    return res.status(500).json({ error: `No manifest for channel: ${channel}` });
  }

  // Client is already on current version
  if (version >= channelManifest.currentVersion) {
    return res.json({
      error: null,
      upToDate: true,
      message: 'Client is up to date'
    });
  }

  // Build response
  const response = {
    error: null,
    upToDate: false,
    version: channelManifest.currentVersion,
    url: channelManifest.downloadBaseUrl,
    files: channelManifest.files,
    binary: null
  };

  // Add binary update if available for the client's OS
  if (channelManifest.binary) {
    const clientOs = (typeof os === 'string' ? os : 'windows').toLowerCase();
    if (channelManifest.binary[clientOs]) {
      response.binary = channelManifest.binary[clientOs];
    }
  }

  res.json(response);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`[updater] Rookhaven Updater API listening on port ${PORT}`);
  const m = loadManifest();
  if (m) {
    console.log(`[updater] RELEASE: v${m.release?.currentVersion}  DEV: v${m.dev?.currentVersion}`);
  }
});
```

### 2.4 `manifest.json` (template — update for each release)

```json
{
  "release": {
    "currentVersion": 1341,
    "downloadBaseUrl": "https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v1.341/",
    "files": {
      "data.zip": "REPLACE_WITH_SHA256_OF_DATA_ZIP"
    },
    "binary": {
      "windows": {
        "file": "RookhavenClient.exe",
        "checksum": "REPLACE_WITH_SHA256_OF_EXE"
      }
    }
  },
  "dev": {
    "currentVersion": 13410,
    "downloadBaseUrl": "https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/dev-1.3410/",
    "files": {
      "data.zip": "REPLACE_WITH_SHA256_OF_DEV_DATA_ZIP"
    },
    "binary": null
  }
}
```

**Note on `files` structure:** The updater module in `updater.lua` expects either a `data.zip` entry (full archive update) or individual file paths. Sending only `data.zip` is sufficient for most updates; it replaces all Lua code at once. Add individual file entries only if you want partial file updates without replacing data.zip.

### 2.5 `.gitignore`

```
node_modules/
```

### 2.6 Deploy on VPS

```bash
# On VPS (as your user, e.g. marcus)
cd /home/marcus
git clone https://github.com/YOUR_USERNAME/rookhaven-updater.git
cd rookhaven-updater
npm ci --omit=dev

# Start with pm2 (install pm2 globally if not present: npm install -g pm2)
pm2 start updater-api.js --name rookhaven-updater
pm2 save
pm2 startup   # follow the output command to enable auto-start on boot
```

Set up a reverse proxy so HTTPS works (Nginx example):

```nginx
server {
    listen 443 ssl;
    server_name updater.rookhaven-ot.com;

    ssl_certificate     /etc/letsencrypt/live/updater.rookhaven-ot.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/updater.rookhaven-ot.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Get a certificate: `certbot --nginx -d updater.rookhaven-ot.com`

**Verify the API works:**

```bash
curl https://updater.rookhaven-ot.com/health
curl -X POST https://updater.rookhaven-ot.com/api/updater \
  -H "Content-Type: application/json" \
  -d '{"version": 1000, "os": "windows"}'
```

---

## 3. Phase 2 — Enable Updater in Client (`init.lua`)

**File:** `c:\RookhavenServerandClientCode\otcv8-rookhaven\init.lua`

**Current state (line 8–15):**
```lua
Services = {
  website = "",
  updater = "",
  stats = "",
  crash = "",
  feedback = "",
  status = ""
}
```

**Change to:**
```lua
Services = {
  website = "",
  updater = "https://updater.rookhaven-ot.com/api/updater",
  stats = "",
  crash = "",
  feedback = "",
  status = ""
}
```

Replace the URL with your actual VPS subdomain. The guard on line 205 (`Services.updater:len() > 4`) will activate the updater module only when this is non-empty.

**IMPORTANT:** This line must be set **before** the first release is built and distributed. Once players have the client without the URL baked in, they can never auto-update.

---

## 4. Phase 3 — Fix Checksum `.lua`/`.luac` Compatibility

### The Problem

**Server** (`Rookhaven/src/protocolgame.cpp`, `validateClientChecksums`):  
Validates against a hard-coded list of paths ending in `.lua`:
```cpp
const std::vector<std::string> criticalFiles = {
    "/modules/corelib/corelib.otmod",
    "/modules/corelib/util.lua",
    "/modules/corelib/globals.lua",
    "/modules/gamelib/gamelib.otmod",
    "/modules/gamelib/game.lua",
    "/modules/gamelib/protocolgame.lua",
    "/modules/game_protocol/protocol.lua",
    "/modules/game_features/features.lua",
};
```

**Client** (`otcv8-rookhaven/modules/client_checksums/checksums.lua`):  
Also uses `.lua` paths in `CRITICAL_FILES`. In dev/debug mode (loose files) this is fine. In release mode (running from `data.zip` with `.luac` bytecode), the Lua files are compiled — `g_resources.fileExists("/modules/corelib/util.lua")` returns `"NOTFOUND"`, causing the hash to be computed on literal `"NOTFOUND"` strings, which will never match the server.

### Fix A — Client: fall back to `.luac` if `.lua` not found

**File:** `c:\RookhavenServerandClientCode\otcv8-rookhaven\modules\client_checksums\checksums.lua`

In the `getFileChecksum` function, after the `fileExists` check, add a fallback:

```lua
-- Generate checksum for a single file
local function getFileChecksum(filepath)
  if checksumCache[filepath] then
    return checksumCache[filepath]
  end
  
  -- In release builds, .lua files are compiled to .luac — try both
  local resolvedPath = filepath
  if not g_resources.fileExists(filepath) then
    local luacPath = filepath:gsub("%.lua$", ".luac")
    if luacPath ~= filepath and g_resources.fileExists(luacPath) then
      resolvedPath = luacPath
    else
      checksumCache[filepath] = "NOTFOUND"
      return "NOTFOUND"
    end
  end
  
  local checksum = g_resources.fileChecksum(resolvedPath)
  checksumCache[filepath] = checksum
  return checksum
end
```

### Fix B — Server: accept both `.lua` and `.luac` checksums

**File:** `c:\RookhavenServerandClientCode\Rookhaven\src\protocolgame.cpp`

In `validateClientChecksums`, extend the expected file lookup to try the `.luac` variant if the `.lua` key is not found in the expected map:

```cpp
std::string combined;
for (const auto& path : criticalFiles) {
    auto it = expected.find(path);
    if (it == expected.end()) {
        // Try .luac variant (release builds compile .lua -> .luac)
        std::string luacPath = path;
        if (luacPath.size() > 4 && luacPath.substr(luacPath.size() - 4) == ".lua") {
            luacPath += "c";
            it = expected.find(luacPath);
        }
    }
    if (it == expected.end()) {
        std::cout << "[Checksum] Missing expected checksum for " << path << std::endl;
        return false;
    }
    combined += it->second + "|";
}
```

This replaces the existing block (starting at the `std::string combined;` declaration) in the function.

### Fix C — Sync the critical files lists

Both the client `CRITICAL_FILES` in `checksums.lua` and the server `criticalFiles` vector in `protocolgame.cpp` **must list exactly the same paths in exactly the same order**. If you add a file to one, add it to both.

---

## 5. Phase 4 — First Release Artifacts

This is the manual process for each release. Once working, this can be scripted (see note at end).

### Step 1 — Build the static client

In Visual Studio or with CMake CLI:

```powershell
cd C:\RookhavenServerandClientCode\otcv8-rookhaven
cmake --preset x64-Release   # or your existing Release preset
cmake --build out/build/x64-Release --config Release
```

With `USE_STATIC_LIBS=ON` the post-build steps will:
1. Compile `.lua` → `.luac` (if `ENABLE_LUAC_RELEASE=ON`)
2. Copy to the output directory

### Step 2 — Install / package

```powershell
cmake --install out/build/x64-Release --prefix dist\RookhavenClient
```

This will:
- Copy `RookhavenClient.exe` to `dist\RookhavenClient\`
- Create `data.zip` containing `init.luac`, `modules/`, `data/`, `layouts/` (bytecode only)

### Step 3 — Compute checksums

```powershell
# Get SHA256 of the exe
$exeHash = (Get-FileHash "dist\RookhavenClient\RookhavenClient.exe" -Algorithm SHA256).Hash.ToLower()
Write-Host "EXE: $exeHash"

# Get SHA256 of data.zip
$zipHash = (Get-FileHash "dist\RookhavenClient\data.zip" -Algorithm SHA256).Hash.ToLower()
Write-Host "data.zip: $zipHash"
```

### Step 4 — Create GitHub Release

1. Push changes to repo
2. GitHub → Releases → "Draft new release"
3. Tag: `v1.341` (match `APP_VERSION 1341` → tag is `v1.{first digit}.{rest}`)
4. Upload assets:
   - `RookhavenClient.exe` (rename from build output if needed)
   - `data.zip`
5. Publish

### Step 5 — Update manifest.json and redeploy

Edit `manifest.json` on the VPS (or in the repo, then pull):

```json
{
  "release": {
    "currentVersion": 1341,
    "downloadBaseUrl": "https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v1.341/",
    "files": {
      "data.zip": "<zipHash from step 3>"
    },
    "binary": {
      "windows": {
        "file": "RookhavenClient.exe",
        "checksum": "<exeHash from step 3>"
      }
    }
  },
  ...
}
```

If manifest.json is part of the API repo, `git push` → `git pull` on VPS. pm2 picks up the new file on the next request (no restart needed since it reads from disk per-request).

### Step 6 — Update server checksum_expected.txt

The OTC post-build already runs `update_server_checksums.lua` which regenerates `checksum_expected.txt`. Copy the updated file to the server:

```
Rookhaven/data/checksum_expected.txt
```

Rebuild and redeploy the game server (or copy the file without rebuild — checksum_expected.txt is read at runtime from disk).

---

## 6. Phase 5 — Release Checklist

Use this for every release. Copy it per version.

```
## Release v1.XXX

### Pre-build
- [ ] Merged all changes to main branch
- [ ] Updated APP_VERSION in init.lua to new version number
- [ ] Verified Services.updater URL is set and correct
- [ ] CRITICAL_FILES in checksums.lua matches criticalFiles in protocolgame.cpp

### Build
- [ ] cmake --build (Release, USE_STATIC_LIBS=ON)
- [ ] cmake --install → dist/RookhavenClient/
- [ ] Verified data.zip was created (contains .luac files, not .lua)
- [ ] Verified RookhavenClient.exe starts and connects to test server

### Checksums
- [ ] Computed SHA256 of RookhavenClient.exe → noted: ________________
- [ ] Computed SHA256 of data.zip → noted: ________________
- [ ] Copied updated checksum_expected.txt to Rookhaven/data/

### GitHub Release
- [ ] Created tag v1.XXX
- [ ] Uploaded RookhavenClient.exe
- [ ] Uploaded data.zip
- [ ] Published release

### API
- [ ] Updated manifest.json with new version + checksums + download URL
- [ ] API health check shows new version: curl /health
- [ ] Test POST with old version number → response includes files and url

### Server
- [ ] Deployed updated checksum_expected.txt to game server
- [ ] Restarted game server (if binary also changed)

### Verification
- [ ] Launched OLD client (APP_VERSION < new) → updater dialog appears
- [ ] Files download successfully
- [ ] After update, client relaunches on new version
- [ ] Launched NEW client (APP_VERSION == new) → no updater, connects normally
- [ ] Checksum validation passes (no [Checksum] errors in server console)
```

---

## 7. Phase 6 — Test Scenarios

Before going live, run all 5 test scenarios:

| # | Scenario | Expected result |
|---|----------|-----------------|
| 1 | Launch client with version < currentVersion, Lua-only update (no binary field) | Files download, game loads with updated code |
| 2 | Launch client with version < currentVersion, binary update available | Exe downloads, client auto-restarts with new binary |
| 3 | Launch client with version == currentVersion | Updater reports "up to date", game loads normally |
| 4 | API is unreachable / returns 500 | Updater shows error, client still loads game (non-blocking) |
| 5 | Downloaded file has wrong checksum (simulate by corrupting file on server) | Updater shows checksum error, does not apply corrupt file |

---

## 8. Troubleshooting Reference

### Updater never triggers

- Check `Services.updater` is set and non-empty in `init.lua`
- Check `g_resources.isLoadedFromArchive()` — client must be running from `data.zip`
- Verify the updater module is present: `modules/updater/updater.lua`

### API returns up-to-date even for old client

- Check `APP_VERSION` in client `init.lua` matches what the API receives
- Print `req.body` in `updater-api.js` to see what the client is sending
- Confirm `currentVersion` in `manifest.json` is greater than client version

### Checksum mismatch on login (server rejects client)

- Compare `CRITICAL_FILES` (client) with `criticalFiles` in `protocolgame.cpp` — must be identical lists in same order
- If running from `data.zip`, the `.lua` fallback to `.luac` fix (Phase 3) must be applied
- Check `data/checksum_expected.txt` was regenerated after the last build
- Run client with log level verbose to see what checksums are being sent

### data.zip not created on install

- Confirm `USE_STATIC_LIBS=ON` is set in CMake configuration
- The install step (`cmake --install`) generates data.zip, not the build step
- Check CMake output for "Creating data.zip" message

### Files keep re-downloading on every launch

- Checksums in `manifest.json` don't match the actual files hosted on GitHub
- Recompute with `Get-FileHash` and update `manifest.json`

---

## Appendix — File Summary

| File | Location | What to change | When |
|------|----------|----------------|------|
| `init.lua` | `otcv8-rookhaven/init.lua` | Set `Services.updater` URL | Phase 2, before first release |
| `checksums.lua` | `otcv8-rookhaven/modules/client_checksums/checksums.lua` | `.lua`→`.luac` fallback in `getFileChecksum` | Phase 3 |
| `protocolgame.cpp` | `Rookhaven/src/protocolgame.cpp` | Accept `.luac` keys in `validateClientChecksums` | Phase 3, rebuild server |
| `updater-api.js` | new repo on VPS | Create fresh | Phase 1 |
| `manifest.json` | new repo on VPS | Create + update per release | Phase 1 + Phase 5 |
| `checksum_expected.txt` | `Rookhaven/data/checksum_expected.txt` | Auto-generated by build, copy to server | Phase 5 per release |
