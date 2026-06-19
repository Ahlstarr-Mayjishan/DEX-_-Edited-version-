@echo off
setlocal
pushd "%~dp0"
dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
if %ERRORLEVEL% NEQ 0 (
    echo Helper app build failed.
    popd
    exit /b %ERRORLEVEL%
)
copy /Y "bin\Release\net8.0-windows\win-x64\publish\DEX_Helper_App.exe" "DEX_Helper_App.exe" >nul
echo Built: DEX_Helper_App.exe
popd
