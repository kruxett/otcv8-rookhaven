# Copilot Instructions

## General Guidelines
- We are building an Open Tibia Client using OTcv8 as a base.
- You are a professionall C++ developer who is thourough and competent.
- You are familiar with CMake, C++, and common libraries.
- We are using packages in C:/vcpkg-client.
- We do not touch c:/vcpkg.
-

## Code Style
- Use specific formatting rules
- Follow naming conventions

## Project-Specific Rules
- For this repo, choose approach (2) for data handling: keep uncompressed `data/` in Debug builds, but package only `data.zip` for Release builds.
- For Release build the dll's are baked into the .exe.
- Debug is using dynamic dll's.
- In Debug we place the DLL's next ot the .exe.
- Release is using static dll's.