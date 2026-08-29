#!/bin/sh

# Colors
C_HEAD="\033[38;2;174;198;207m"
C_SUCC="\033[38;2;119;221;119m"
C_WARN="\033[38;2;253;253;150m"
C_FAIL="\033[38;2;255;105;97m"
C_TEXT="\033[38;2;190;190;190m"
C_RST="\033[0m"

printf "${C_HEAD}=> Building ipapi CLI (Native)...${C_RST}\n"

# 1. Native Build (Linux / macOS / Windows MSYS)
# Using -std=c++17 for std::filesystem support
g++ -std=c++17 main.cpp -o ipa -lcurl -O3

if [ $? -eq 0 ]; then
    printf "${C_SUCC}=> Native build successful!${C_RST} Executable created: ./ipa\n"
    printf "${C_TEXT}=> To install globally on Linux/macOS: sudo cp ipa /usr/local/bin/${C_RST}\n"
else
    printf "${C_FAIL}=> Native build failed.${C_RST}\n"
    exit 1
fi

echo ""

# 2. Windows Cross-Compilation (if mingw-w64 is available)
if command -v x86_64-w64-mingw32-g++ >/dev/null 2>&1; then
    printf "${C_HEAD}=> Found MinGW. Cross-compiling for Windows (x86_64)...${C_RST}\n"
    x86_64-w64-mingw32-g++ -std=c++17 main.cpp -o ipa.exe -lcurl -O3
    if [ $? -eq 0 ]; then
        printf "${C_SUCC}=> Windows build successful!${C_RST} Executable created: ./ipa.exe\n"
    else
        printf "${C_FAIL}=> Windows build failed. (Make sure you have libcurl compiled for MinGW)${C_RST}\n"
    fi
else
    printf "${C_WARN}=> MinGW (x86_64-w64-mingw32-g++) not found. Skipping Windows cross-compilation.${C_RST}\n"
    printf "${C_TEXT}   To build for Windows from Linux, install mingw-w64 and Windows libcurl headers.${C_RST}\n"
fi

echo ""

# 3. macOS Cross-Compilation (if osxcross is available)
if command -v o64-clang++ >/dev/null 2>&1; then
    printf "${C_HEAD}=> Found osxcross. Cross-compiling for macOS...${C_RST}\n"
    o64-clang++ -std=c++17 main.cpp -o ipa-mac -lcurl -O3
    if [ $? -eq 0 ]; then
        printf "${C_SUCC}=> macOS build successful!${C_RST} Executable created: ./ipa-mac\n"
    else
        printf "${C_FAIL}=> macOS build failed.${C_RST}\n"
    fi
else
    printf "${C_WARN}=> osxcross (o64-clang++) not found. Skipping macOS cross-compilation.${C_RST}\n"
    printf "${C_TEXT}   Note: You can compile natively on a Mac simply by running this build.sh script on macOS.${C_RST}\n"
fi
