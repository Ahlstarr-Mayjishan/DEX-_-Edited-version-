# DEX++ Helper App

Native desktop wrapper for the DEX++ local helper dashboard.

Requirements:

- .NET SDK 8.0 for building
- Microsoft Edge WebView2 Runtime for running

Build:

```bat
build.bat
```

Run:

```bat
DEX_Helper_App.exe
```

The app starts `..\HelperServer\DEX_Helper.exe` in hidden/headless mode when the helper is not already running.
