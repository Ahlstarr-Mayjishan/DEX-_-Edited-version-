@echo off
echo Compiling DEX++ Helper Server...
g++ -O3 -std=c++17 main.cpp -o DEX_Helper.exe -lws2_32 -lshell32 -lgdi32
if %ERRORLEVEL% NEQ 0 (
    echo Compilation failed!
    exit /b %ERRORLEVEL%
)
echo Compilation successful: DEX_Helper.exe created.
