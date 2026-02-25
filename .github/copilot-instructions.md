# Copilot Instructions

## General Guidelines
- We are building an Open Tibia Client using OTcv8 (OT Client V8) as a base.
- You are a professional C++ developer who is thorough and competent.
- You are familiar with CMake (minimum version 3.25, using Ninja generator), C++, and common libraries.
- The server is TFS 1.5 Downgraded 8.6 by Nekiro/Angelion.

## Code Style
- Use specific formatting rules.
- Follow naming conventions.

## Project-Specific Rules
- For this repo, choose approach (2) for data handling: keep uncompressed `data/` in Debug builds, but package only `data.zip` for Release builds.
- For Release builds, the DLLs are baked into the .exe (static DLLs).
- Debug builds use dynamic DLLs placed next to the .exe.
- For Release and DevRelease builds, compile Lua scripts to `.luac`, delete `.lua` files in `modules/` and `data/`, and rebuild `data.zip` with bytecode only while keeping sources in the repo for development.

## Game Mechanics
- Corpse glow is handled via OTClient extended opcodes:
  - Server (TFS 1.5 downgraded 8.6) sends unlooted corpse notifications using `sendExtendedOpcode(1, payload)` with extended opcode `0x32` and extended id `1`.
  - On the wire, this is Tibia opcode `0x32` (`GameServerExtendedOpcode`), then extended id `1`, then a UTF-8 string payload.
  - Payload format:
    - Mark: `"mark:x,y,z"` (add glow and track by position).
    - Clear: `"clear:x,y,z"` (remove glow and clear tracking by position).
  - The client listens to extended opcode id `1` and must never treat `0x01` as a normal game opcode.
