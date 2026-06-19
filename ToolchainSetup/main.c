#define WIN32_LEAN_AND_MEAN

#include <windows.h>
#include <shellapi.h>
#include <stdio.h>
#include <string.h>

static const char* APP_INSTALLER_URL = "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1";

static int command_exists(const char* command) {
    char resolved[MAX_PATH + 1];
    return SearchPathA(NULL, command, ".exe", MAX_PATH, resolved, NULL) > 0;
}

static void print_status(void) {
    printf("\nDEX++ toolchain status\n");
    printf("  Python: %s\n", command_exists("python") || command_exists("py") ? "available" : "missing");
    printf("  Cargo:  %s\n", command_exists("cargo") ? "available" : "missing");
    printf("  g++:    %s\n", command_exists("g++") ? "available" : "missing");
    printf("  winget: %s\n\n", command_exists("winget") ? "available" : "missing");
}

static int confirm_install(void) {
    char answer[16] = {0};
    printf(
        "Install or upgrade Python 3.14, Rustup, and WinLibs g++?\n"
        "Only these DEX++ toolchain packages will be changed. [y/N]: "
    );
    if (!fgets(answer, sizeof(answer), stdin)) return 0;
    return answer[0] == 'y' || answer[0] == 'Y';
}

static int install_or_upgrade(void) {
    const char* command =
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \""
        "$ErrorActionPreference='Continue';"
        "winget install --id Python.Python.3.14 --exact --source winget --accept-package-agreements --accept-source-agreements;"
        "winget upgrade --id Python.Python.3.14 --exact --source winget --accept-package-agreements --accept-source-agreements;"
        "winget install --id Rustlang.Rustup --exact --source winget --accept-package-agreements --accept-source-agreements;"
        "winget upgrade --id Rustlang.Rustup --exact --source winget --accept-package-agreements --accept-source-agreements;"
        "if (Get-Command rustup -ErrorAction SilentlyContinue) { rustup update stable };"
        "winget install --id BrechtSanders.WinLibs.MCF.UCRT --exact --source winget --accept-package-agreements --accept-source-agreements;"
        "winget upgrade --id BrechtSanders.WinLibs.MCF.UCRT --exact --source winget --accept-package-agreements --accept-source-agreements;"
        "Write-Host ''; Write-Host 'DEX++ toolchain operation finished. Restart the helper after closing this window.';"
        "Read-Host 'Press Enter to close'\"";

    if (!command_exists("winget")) {
        printf("Windows Package Manager is missing. Opening Microsoft App Installer.\n");
        ShellExecuteA(NULL, "open", APP_INSTALLER_URL, NULL, NULL, SW_SHOWNORMAL);
        return 2;
    }
    if (!confirm_install()) {
        printf("No changes were made.\n");
        return 0;
    }
    return system(command);
}

int main(int argc, char** argv) {
    SetConsoleTitleA("DEX++ Toolchain Setup");
    print_status();

    if (argc > 1 && strcmp(argv[1], "--check") == 0) {
        return 0;
    }

    printf("This utility manages build tools only. The prebuilt DEX_Helper.exe can run without them.\n");
    printf("Python enables deep analysis, Rust builds the fast analyzer, and g++ rebuilds the helper.\n\n");

    {
        int result = install_or_upgrade();
        print_status();
        return result;
    }
}
