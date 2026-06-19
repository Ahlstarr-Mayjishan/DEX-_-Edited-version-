@echo off
echo Compiling DEX++ Toolchain Setup...
gcc -O2 main.c -o ..\HelperServer\DEX_Language_Manager.exe -lshell32
if %ERRORLEVEL% NEQ 0 (
    echo Compilation failed!
    exit /b %ERRORLEVEL%
)
echo Compilation successful: HelperServer\DEX_Language_Manager.exe created.
