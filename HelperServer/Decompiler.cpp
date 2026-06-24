#include "Decompiler.h"
#include "Index.h" // For trim_copy

namespace {

std::string env_value(const char* name) {
    char buffer[MAX_PATH * 4];
    DWORD len = GetEnvironmentVariableA(name, buffer, static_cast<DWORD>(sizeof(buffer)));
    if (len == 0 || len >= sizeof(buffer)) {
        return "";
    }
    return std::string(buffer, len);
}

bool file_exists_a(const std::string& path) {
    DWORD attrs = GetFileAttributesA(path.c_str());
    return attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY);
}

std::string dirname_of(const std::string& path) {
    size_t pos = path.find_last_of("\\/");
    if (pos == std::string::npos) {
        return ".";
    }
    return path.substr(0, pos);
}

std::string resolve_decompiler_exe_path() {
    const char* env_names[] = {"DEX_DECOMPILER_PATH", "POTASSIUM_DECOMPILER_PATH", nullptr};
    for (int i = 0; env_names[i]; ++i) {
        std::string configured = env_value(env_names[i]);
        if (!configured.empty() && file_exists_a(configured)) {
            return configured;
        }
    }

    const char* candidates[] = {
        "Decompiler.exe",
        "Potassium\\bin\\Decompiler.exe",
        "D:\\Exploiter\\Potassium\\bin\\Decompiler.exe",
        nullptr,
    };
    for (int i = 0; candidates[i]; ++i) {
        if (file_exists_a(candidates[i])) {
            return candidates[i];
        }
    }
    return "";
}

} // namespace

// Check and auto-launch Potassium Decompiler if not running
void ensure_decompiler_running() {
    struct addrinfo* result = NULL;
    struct addrinfo hints;
    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    int iResult = getaddrinfo("::1", "56535", &hints, &result);
    if (iResult != 0) {
        iResult = getaddrinfo("127.0.0.1", "56535", &hints, &result);
    }
    if (iResult == 0) {
        SOCKET ConnectSocket = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
        if (ConnectSocket != INVALID_SOCKET) {
            iResult = connect(ConnectSocket, result->ai_addr, (int)result->ai_addrlen);
            if (iResult != SOCKET_ERROR) {
                closesocket(ConnectSocket);
                freeaddrinfo(result);
                return; // Already running!
            }
            closesocket(ConnectSocket);
        }
        freeaddrinfo(result);
    }

    std::cout << "[Decompiler] Potassium Decompiler is offline. Launching Decompiler.exe..." << std::endl;
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    std::string path = resolve_decompiler_exe_path();
    if (path.empty()) {
        std::cerr << "[Decompiler] Decompiler.exe was not found. Set DEX_DECOMPILER_PATH to the executable path." << std::endl;
        return;
    }
    std::string dir = dirname_of(path);
    std::vector<char> command_line(path.begin(), path.end());
    command_line.push_back('\0');

    BOOL success = CreateProcessA(
        path.c_str(),
        command_line.data(),
        NULL,
        NULL,
        FALSE,
        CREATE_NO_WINDOW,
        NULL,
        dir.c_str(),
        &si,
        &pi
    );

    if (success) {
        std::cout << "[Decompiler] Successfully launched Decompiler.exe (PID: " << pi.dwProcessId << ")" << std::endl;
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        std::this_thread::sleep_for(std::chrono::milliseconds(1000)); // Wait for server to bind
    } else {
        std::cerr << "[Decompiler] Failed to launch Decompiler.exe. Error code: " << GetLastError() << std::endl;
    }
}

// Proxies decompile request to local Rust luau-lifter server
std::string decompile_bytecode(const std::string& bytecode) {
    if (bytecode.empty()) {
        return "-- Decompile failed: empty bytecode payload.";
    }

    ensure_decompiler_running();

    std::string boundary = "----DarkDexHelperBoundary";
    
    // Construct the multipart body
    std::string body;
    body += "--" + boundary + "\r\n";
    body += "Content-Disposition: form-data; name=\"bytecode\"; filename=\"script.luac\"\r\n";
    body += "Content-Type: application/octet-stream\r\n\r\n";
    body += bytecode;
    body += "\r\n--" + boundary + "--\r\n";

    // Construct the HTTP headers
    std::stringstream request;
    request << "POST /decompile HTTP/1.1\r\n"
            << "Host: [::1]:56535\r\n"
            << "Content-Type: multipart/form-data; boundary=" << boundary << "\r\n"
            << "Content-Length: " << body.length() << "\r\n"
            << "Connection: close\r\n\r\n"
            << body;

    std::string request_str = request.str();

    // Setup connection
    struct addrinfo* result = NULL;
    struct addrinfo hints;
    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    int iResult = getaddrinfo("::1", "56535", &hints, &result);
    if (iResult != 0) {
        iResult = getaddrinfo("127.0.0.1", "56535", &hints, &result);
    }
    if (iResult != 0) {
        return "-- Error: getaddrinfo failed for decompiler server.";
    }

    SOCKET ConnectSocket = INVALID_SOCKET;
    for (struct addrinfo* ptr = result; ptr != NULL; ptr = ptr->ai_next) {
        ConnectSocket = socket(ptr->ai_family, ptr->ai_socktype, ptr->ai_protocol);
        if (ConnectSocket == INVALID_SOCKET) {
            continue;
        }

        iResult = connect(ConnectSocket, ptr->ai_addr, (int)ptr->ai_addrlen);
        if (iResult == SOCKET_ERROR) {
            closesocket(ConnectSocket);
            ConnectSocket = INVALID_SOCKET;
            continue;
        }
        break;
    }

    freeaddrinfo(result);

    if (ConnectSocket == INVALID_SOCKET) {
        return "-- Error: Could not connect to Potassium Decompiler server (port 56535).";
    }
    DWORD socket_timeout_ms = 15000;
    setsockopt(ConnectSocket, SOL_SOCKET, SO_SNDTIMEO, reinterpret_cast<const char*>(&socket_timeout_ms), sizeof(socket_timeout_ms));
    setsockopt(ConnectSocket, SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<const char*>(&socket_timeout_ms), sizeof(socket_timeout_ms));

    // Send the request
    size_t total_sent = 0;
    while (total_sent < request_str.size()) {
        int bytes_sent = send(
            ConnectSocket,
            request_str.data() + total_sent,
            static_cast<int>(std::min<size_t>(request_str.size() - total_sent, INT_MAX)),
            0
        );
        if (bytes_sent == SOCKET_ERROR || bytes_sent == 0) {
            closesocket(ConnectSocket);
            return "-- Decompile failed: incomplete request send to Potassium Decompiler.";
        }
        total_sent += static_cast<size_t>(bytes_sent);
    }

    // Read the response
    std::string response;
    char recvbuf[BUFFER_SIZE];
    int bytes_received;
    do {
        bytes_received = recv(ConnectSocket, recvbuf, BUFFER_SIZE, 0);
        if (bytes_received > 0) {
            response.append(recvbuf, bytes_received);
            if (response.size() > 10 * 1024 * 1024) {
                closesocket(ConnectSocket);
                return "-- Decompile failed: response from Potassium Decompiler is too large.";
            }
        }
    } while (bytes_received > 0);

    closesocket(ConnectSocket);

    // Parse the HTTP response body
    size_t header_end = response.find("\r\n\r\n");
    if (header_end == std::string::npos) {
        return "-- Error: Invalid HTTP response from Decompiler.";
    }

    // Check status code
    std::string status_line = response.substr(0, response.find("\r\n"));
    if (status_line.find("200") == std::string::npos) {
        return "-- Error: Decompiler server returned non-200 status:\n-- " + status_line;
    }

    std::string response_body = response.substr(header_end + 4);
    if (trim_copy(response_body).empty()) {
        return "-- Decompile failed: Potassium Decompiler returned an empty response.";
    }
    return response_body;
}
