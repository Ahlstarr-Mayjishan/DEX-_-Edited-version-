#include "Common.h"
#include "Dashboard.h"
#include "Auth.h"
#include "Index.h"
#include "Win32App.h"
#include "Toolchain.h"
#include "Decompiler.h"
#include "HttpUtil.h"
#include "Routes.h"

// Link with ws2_32.lib
#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "wininet.lib")

std::atomic<int> g_active_clients{0};
ULONGLONG g_last_mcp_time = 0;

#include "WsProtocol.h"

std::mutex g_ws_mutex;
std::map<long long, SOCKET> g_roblox_ws_map;
SOCKET g_dashboard_ws = INVALID_SOCKET;
static constexpr size_t MAX_SYNC_WS_FILES_PER_FRAME = 200;
static constexpr size_t MAX_SYNC_WS_FILE_BYTES = 512 * 1024;
static constexpr size_t MAX_SYNC_WS_PAYLOAD_BYTES = 2 * 1024 * 1024;

static long long get_request_place_id_from_path_and_headers(const std::string& path, const std::string& headers) {
    size_t pos = path.find("placeId=");
    if (pos != std::string::npos) {
        size_t start = pos + 8;
        size_t end = start;
        while (end < path.size() && std::isdigit(static_cast<unsigned char>(path[end]))) {
            end++;
        }
        if (end > start) {
            try {
                return std::stoll(path.substr(start, end - start));
            } catch (...) {}
        }
    }
    return get_request_place_id(headers);
}
static std::wstring get_ws_sync_dir_w() {
    DWORD attrs = GetFileAttributesA("..\\DEX++.luau");
    if (attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY)) {
        return L"..\\workspace_sync";
    }
    return L"workspace_sync";
}

static std::wstring get_ws_sync_path_w(const std::wstring& relative_path) {
    DWORD attrs = GetFileAttributesA("..\\DEX++.luau");
    if (attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY)) {
        return L"..\\workspace_sync\\" + relative_path;
    }
    return L"workspace_sync\\" + relative_path;
}

inline void handle_client_ws(SOCKET ClientSocket, const std::string& request_headers, const std::string& path) {
    if (!perform_ws_handshake(ClientSocket, request_headers)) return;
    
    long long place_id = get_request_place_id_from_path_and_headers(path, request_headers);
    
    {
        std::lock_guard<std::mutex> lock(g_ws_mutex);
        auto it = g_roblox_ws_map.find(place_id);
        if (it != g_roblox_ws_map.end()) {
            closesocket(it->second);
        }
        g_roblox_ws_map[place_id] = ClientSocket;
        if (g_selected_place_id == 0) {
            g_selected_place_id = place_id;
        }
    }
    
    std::cout << "Roblox client (Place ID " << place_id << ") connected via WebSockets." << std::endl;
    
    std::string payload;
    while (read_ws_text_frame(ClientSocket, payload)) {
        SOCKET dash = INVALID_SOCKET;
        bool dashValid = false;
        {
            std::lock_guard<std::mutex> lock(g_ws_mutex);
            dash = g_dashboard_ws;
            dashValid = (dash != INVALID_SOCKET);
        }
        if (dashValid) {
            std::lock_guard<std::mutex> lock(g_ws_mutex);
            if (g_dashboard_ws == dash) {
                if (!send_ws_text_frame(dash, payload)) {
                    closesocket(g_dashboard_ws);
                    g_dashboard_ws = INVALID_SOCKET;
                }
            }
        }
    }
    
    {
        std::lock_guard<std::mutex> lock(g_ws_mutex);
        auto it = g_roblox_ws_map.find(place_id);
        if (it != g_roblox_ws_map.end() && it->second == ClientSocket) {
            g_roblox_ws_map.erase(it);
        }
        if (g_selected_place_id == place_id) {
            if (!g_roblox_ws_map.empty()) {
                g_selected_place_id = g_roblox_ws_map.begin()->first;
            } else {
                g_selected_place_id = 0;
            }
        }
    }
    close_client(ClientSocket);
    std::cout << "Roblox client (Place ID " << place_id << ") disconnected." << std::endl;
}

inline void handle_dashboard_ws(SOCKET ClientSocket, const std::string& request_headers) {
    if (!request_has_valid_session(request_headers)) {
        send_response(ClientSocket, 403, "Forbidden", "WebSocket session token is required.");
        close_client(ClientSocket);
        return;
    }
    if (!perform_ws_handshake(ClientSocket, request_headers)) return;
    
    {
        std::lock_guard<std::mutex> lock(g_ws_mutex);
        if (g_dashboard_ws != INVALID_SOCKET) {
            closesocket(g_dashboard_ws);
        }
        g_dashboard_ws = ClientSocket;
    }
    
    std::cout << "Dashboard connected via WebSockets." << std::endl;
    
    std::string payload;
    while (read_ws_text_frame(ClientSocket, payload)) {
        SOCKET roblox = INVALID_SOCKET;
        bool robloxValid = false;
        {
            std::lock_guard<std::mutex> lock(g_ws_mutex);
            auto it = g_roblox_ws_map.find(g_selected_place_id);
            if (it != g_roblox_ws_map.end()) {
                roblox = it->second;
                robloxValid = true;
            } else if (!g_roblox_ws_map.empty()) {
                roblox = g_roblox_ws_map.begin()->second;
                robloxValid = true;
            }
        }
        if (robloxValid && roblox != INVALID_SOCKET) {
            if (!send_ws_text_frame(roblox, payload)) {
                std::lock_guard<std::mutex> lock(g_ws_mutex);
                for (auto it = g_roblox_ws_map.begin(); it != g_roblox_ws_map.end(); ) {
                    if (it->second == roblox) {
                        closesocket(it->second);
                        it = g_roblox_ws_map.erase(it);
                    } else {
                        ++it;
                    }
                }
            }
        }
    }
    
    {
        std::lock_guard<std::mutex> lock(g_ws_mutex);
        if (g_dashboard_ws == ClientSocket) {
            g_dashboard_ws = INVALID_SOCKET;
        }
    }
    close_client(ClientSocket);
    std::cout << "Dashboard disconnected." << std::endl;
}

// Handle WebSocket client upgrades and updates
inline void handle_ws_client(SOCKET ClientSocket, const std::string& request_headers) {
    if (!perform_ws_handshake(ClientSocket, request_headers)) return;
    
    unsigned long long client_time = 0;
    FILETIME current_ft;
    GetSystemTimeAsFileTime(&current_ft);
    ULARGE_INTEGER current_ui;
    current_ui.LowPart = current_ft.dwLowDateTime;
    current_ui.HighPart = current_ft.dwHighDateTime;
    client_time = current_ui.QuadPart;
    int idle_polls = 0;
    
    while (!g_shutdown_requested.load()) {
        fd_set read_fds;
        FD_ZERO(&read_fds);
        FD_SET(ClientSocket, &read_fds);
        
        timeval timeout;
        int poll_ms = idle_polls > 20 ? 2000 : (idle_polls > 5 ? 1000 : 500);
        timeout.tv_sec = poll_ms / 1000;
        timeout.tv_usec = (poll_ms % 1000) * 1000;
        
        int sel = select(0, &read_fds, NULL, NULL, &timeout);
        if (sel == SOCKET_ERROR) {
            break;
        }
        
        if (sel > 0) {
            char peek_buf[2];
            int rec = recv(ClientSocket, peek_buf, 2, MSG_PEEK);
            if (rec <= 0) {
                break;
            }
            
            unsigned char first_byte = peek_buf[0];
            unsigned char opcode = first_byte & 0x0F;
            if (opcode == 0x08) {
                break;
            }
            
            char discard_buf[1024];
            int bytes_discarded = recv(ClientSocket, discard_buf, sizeof(discard_buf), 0);
            if (bytes_discarded <= 0) {
                break;
            }
        }
        
        std::wstring sync_dir = get_ws_sync_dir_w();
        CreateDirectoryW(sync_dir.c_str(), NULL);
        std::vector<FileInfo> files;
        scan_directory_recursive(sync_dir, L"", files);
        
        bool has_changes = false;
        unsigned long long latest_time = client_time;
        for (const auto& file : files) {
            if (file.last_write_time > client_time) {
                has_changes = true;
                if (file.last_write_time > latest_time) {
                    latest_time = file.last_write_time;
                }
            }
        }
        
        if (has_changes) {
            std::stringstream json;
            json << "{\"ok\":true,\"files\":[";
            bool first_file = true;
            bool truncated = false;
            size_t files_in_frame = 0;
            size_t payload_budget = 0;
            unsigned long long frame_latest_time = client_time;
            for (const auto& file : files) {
                if (file.last_write_time > client_time) {
                    if (files_in_frame >= MAX_SYNC_WS_FILES_PER_FRAME) {
                        truncated = true;
                        break;
                    }
                    std::wstring full_w = get_ws_sync_path_w(to_wstring(file.relative_path));
                    std::ifstream in(full_w.c_str(), std::ios::binary);
                    std::string src = "";
                    if (in.is_open()) {
                        in.seekg(0, std::ios::end);
                        std::streamoff size = in.tellg();
                        in.seekg(0, std::ios::beg);
                        if (size > static_cast<std::streamoff>(MAX_SYNC_WS_FILE_BYTES)) {
                            truncated = true;
                            frame_latest_time = std::max(frame_latest_time, file.last_write_time);
                            continue;
                        }
                        src.assign(static_cast<size_t>(std::max<std::streamoff>(0, size)), '\0');
                        if (!src.empty()) {
                            in.read(&src[0], static_cast<std::streamsize>(src.size()));
                        }
                        in.close();
                    }
                    if (payload_budget + src.size() > MAX_SYNC_WS_PAYLOAD_BYTES) {
                        truncated = true;
                        break;
                    }
                    
                    std::string script_path = "";
                    std::string rel = file.relative_path;
                    if (rel.size() > 5 && rel.substr(rel.size() - 5) == ".luau") {
                        rel = rel.substr(0, rel.size() - 5);
                    }
                    for (char c : rel) {
                        if (c == '\\') {
                            script_path += '.';
                        } else {
                            script_path += c;
                        }
                    }
                    
                    if (!first_file) json << ",";
                    first_file = false;
                    
                    json << "{\"path\":\"" << escape_json(script_path) << "\","
                         << "\"source\":\"" << escape_json(src) << "\","
                         << "\"timestamp\":" << file.last_write_time << "}";
                    payload_budget += src.size();
                    files_in_frame++;
                    frame_latest_time = std::max(frame_latest_time, file.last_write_time);
                }
            }
            
            FILETIME ft;
            GetSystemTimeAsFileTime(&ft);
            ULARGE_INTEGER ui;
            ui.LowPart = ft.dwLowDateTime;
            ui.HighPart = ft.dwHighDateTime;
            latest_time = truncated ? frame_latest_time : std::max(latest_time, ui.QuadPart);
            
            json << "],\"timestamp\":" << latest_time
                 << ",\"truncated\":" << (truncated ? "true" : "false") << "}";
            
            if (!send_ws_text_frame(ClientSocket, json.str())) {
                break;
            }
            client_time = latest_time;
            idle_polls = 0;
        } else {
            idle_polls++;
        }
    }
    
    close_client(ClientSocket);
}

size_t find_header_case_insensitive(const std::string& request, const std::string& header_name) {
    std::string lower_request = lower_copy(request);
    std::string lower_header = lower_copy(header_name);
    return lower_request.find(lower_header);
}

bool parse_content_length(const std::string& request, size_t& content_length, std::string& error) {
    content_length = 0;
    size_t cl_pos = find_header_case_insensitive(request, "Content-Length:");
    if (cl_pos == std::string::npos) return true;

    size_t cl_end = request.find("\r\n", cl_pos);
    if (cl_end == std::string::npos) cl_end = request.size();

    std::string cl_str = trim_copy(request.substr(cl_pos + 15, cl_end - (cl_pos + 15)));
    if (cl_str.empty()) {
        error = "empty Content-Length header";
        return false;
    }

    try {
        size_t parsed_chars = 0;
        unsigned long long parsed = std::stoull(cl_str, &parsed_chars, 10);
        if (parsed_chars != cl_str.size()) {
            error = "invalid Content-Length value";
            return false;
        }
        if (parsed > MAX_BODY_SIZE) {
            error = "request body too large";
            return false;
        }
        content_length = static_cast<size_t>(parsed);
        return true;
    } catch (...) {
        error = "invalid Content-Length value";
        return false;
    }
}

void handle_client(SOCKET ClientSocket) {
    std::vector<char> recvbuf(BUFFER_SIZE);
    std::string request_data = "";
    int bytes_received = recv(ClientSocket, recvbuf.data(), BUFFER_SIZE - 1, 0);

    if (bytes_received > 0) {
        recvbuf[bytes_received] = '\0';
        request_data.append(recvbuf.data(), bytes_received);

        size_t header_end = request_data.find("\r\n\r\n");
        while (header_end == std::string::npos && request_data.size() < MAX_HEADER_SIZE) {
            int extra = recv(ClientSocket, recvbuf.data(), BUFFER_SIZE - 1, 0);
            if (extra <= 0) break;
            recvbuf[extra] = '\0';
            request_data.append(recvbuf.data(), extra);
            header_end = request_data.find("\r\n\r\n");
        }

        if (header_end == std::string::npos) {
            send_response(ClientSocket, 400, "Bad Request", "Malformed HTTP request headers.");
            close_client(ClientSocket);
            return;
        }
        if (header_end > MAX_HEADER_SIZE) {
            send_response(ClientSocket, 413, "Payload Too Large", "HTTP headers are too large.");
            close_client(ClientSocket);
            return;
        }
        if (!require_allowed_host(ClientSocket, request_data.substr(0, header_end))) {
            close_client(ClientSocket);
            return;
        }

        if (request_data.find("X-MCP-Client:") != std::string::npos) {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_last_mcp_time = GetTickCount64();
        }

        std::stringstream ss(request_data.substr(0, header_end));
        std::string method, path, protocol;
        ss >> method >> path >> protocol;
        std::string route_path = path;
        size_t query_pos = route_path.find('?');
        if (query_pos != std::string::npos) {
            route_path = route_path.substr(0, query_pos);
        }

        std::string body = request_data.substr(header_end + 4);
        size_t content_len = 0;
        std::string content_error;
        if (!parse_content_length(request_data.substr(0, header_end), content_len, content_error)) {
            send_response(ClientSocket, 400, "Bad Request", content_error);
            close_client(ClientSocket);
            return;
        }
        if (body.size() > MAX_BODY_SIZE) {
            send_response(ClientSocket, 413, "Payload Too Large", "Request body is too large.");
            close_client(ClientSocket);
            return;
        }
        while (body.size() < content_len) {
            int extra = recv(ClientSocket, recvbuf.data(), BUFFER_SIZE - 1, 0);
            if (extra <= 0) break;
            recvbuf[extra] = '\0';
            body.append(recvbuf.data(), extra);
        }
        if (body.size() < content_len) {
            send_response(ClientSocket, 400, "Bad Request", "Incomplete request body.");
            close_client(ClientSocket);
            return;
        }

        if (method == "OPTIONS") {
            send_response(ClientSocket, 204, "No Content", "");
        } else if (route_path == "/sync-ws" && method == "GET") {
            handle_ws_client(ClientSocket, request_data);
            return;
        } else if (route_path == "/client-ws" && method == "GET") {
            handle_client_ws(ClientSocket, request_data, path);
            return;
        } else if (route_path == "/dashboard-ws" && method == "GET") {
            handle_dashboard_ws(ClientSocket, request_data);
            return;
        } else {
            RouteDispatchResult route_result = dispatch_http_routes(ClientSocket, method, route_path, body, request_data);
            if (route_result == RouteDispatchResult::NotFound) {
                send_response(ClientSocket, 404, "Not Found", "404 Route Not Found");
            } else if (route_result == RouteDispatchResult::CloseConnection) {
                return;
            }
        }
    }

    close_client(ClientSocket);
}

int main() {
    SetConsoleTitleW(L"DEX++ Local Helper");

    HANDLE instance_mutex = CreateMutexW(NULL, FALSE, INSTANCE_MUTEX_NAME);
    if (instance_mutex == NULL) {
        show_startup_notice(L"DEX++ Helper could not create its single-instance lock.", false);
        return 1;
    }
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        show_startup_notice(
            L"DEX++ Helper is already running on port 8080.\n\n"
            L"The existing dashboard will be opened instead of starting a duplicate server.",
            true
        );
        CloseHandle(instance_mutex);
        return 0;
    }
    SetConsoleCtrlHandler(helper_console_control, TRUE);

    WSADATA wsaData;
    int iResult;

    SOCKET ListenSocket = INVALID_SOCKET;
    SOCKET ClientSocket = INVALID_SOCKET;

    struct addrinfo* result = NULL;
    struct addrinfo hints;

    // Initialize Winsock
    iResult = WSAStartup(MAKEWORD(2, 2), &wsaData);
    if (iResult != 0) {
        std::cerr << "WSAStartup failed with error: " << iResult << std::endl;
        show_startup_notice(L"DEX++ Helper could not initialize Windows networking.", false);
        CloseHandle(instance_mutex);
        return 1;
    }

    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    hints.ai_flags = 0;

    // Resolve the server address and port
    iResult = getaddrinfo("127.0.0.1", DEFAULT_PORT, &hints, &result);
    if (iResult != 0) {
        std::cerr << "getaddrinfo failed with error: " << iResult << std::endl;
        WSACleanup();
        show_startup_notice(L"DEX++ Helper could not resolve its local listening address.", false);
        CloseHandle(instance_mutex);
        return 1;
    }

    // Create a SOCKET for the server to listen for client connections
    ListenSocket = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
    if (ListenSocket == INVALID_SOCKET) {
        std::cerr << "socket failed with error: " << WSAGetLastError() << std::endl;
        freeaddrinfo(result);
        WSACleanup();
        show_startup_notice(L"DEX++ Helper could not create its local server socket.", false);
        CloseHandle(instance_mutex);
        return 1;
    }

    // Setup the TCP listening socket
    iResult = bind(ListenSocket, result->ai_addr, static_cast<int>(result->ai_addrlen));
    if (iResult == SOCKET_ERROR) {
        int bind_error = WSAGetLastError();
        std::cerr << "bind failed with error: " << bind_error << std::endl;
        freeaddrinfo(result);
        closesocket(ListenSocket);
        WSACleanup();
        if (bind_error == WSAEADDRINUSE) {
            show_startup_notice(
                L"DEX++ Helper could not start because port 8080 is already in use.\n\n"
                L"Close the application using port 8080, then start the helper again.",
                false
            );
        } else {
            show_startup_notice(L"DEX++ Helper could not bind to localhost port 8080.", false);
        }
        CloseHandle(instance_mutex);
        return 1;
    }

    freeaddrinfo(result);

    iResult = listen(ListenSocket, SOMAXCONN);
    if (iResult == SOCKET_ERROR) {
        std::cerr << "listen failed with error: " << WSAGetLastError() << std::endl;
        closesocket(ListenSocket);
        WSACleanup();
        show_startup_notice(L"DEX++ Helper created its socket but could not begin listening.", false);
        CloseHandle(instance_mutex);
        return 1;
    }

    std::string load_result = load_index_response();
    load_auth_credentials();
    std::cout << "DEX++ C++ Local Helper Server listening on http://127.0.0.1:" << DEFAULT_PORT << " ..." << std::endl;
    std::cout << "Index load: " << load_result << std::endl;
    std::cout << "Dashboard: http://localhost:" << DEFAULT_PORT << "/" << std::endl;
    open_dashboard();

    while (!g_shutdown_requested.load()) {
        // Accept a client socket
        ClientSocket = accept(ListenSocket, NULL, NULL);
        if (ClientSocket == INVALID_SOCKET) {
            std::cerr << "accept failed with error: " << WSAGetLastError() << std::endl;
            continue;
        }
        if (g_shutdown_requested.load()) {
            close_client(ClientSocket);
            break;
        }
        DWORD client_timeout_ms = CLIENT_SOCKET_TIMEOUT_MS;
        setsockopt(ClientSocket, SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<const char*>(&client_timeout_ms), sizeof(client_timeout_ms));
        setsockopt(ClientSocket, SOL_SOCKET, SO_SNDTIMEO, reinterpret_cast<const char*>(&client_timeout_ms), sizeof(client_timeout_ms));

        if (g_active_clients.load() >= MAX_CLIENT_THREADS) {
            send_response(ClientSocket, 503, "Service Unavailable", "DEX++ Helper is busy. Try again shortly.");
            close_client(ClientSocket);
            continue;
        }

        g_active_clients.fetch_add(1);
        std::thread([ClientSocket]() {
            try {
                handle_client(ClientSocket);
            } catch (...) {
                close_client(ClientSocket);
            }
            g_active_clients.fetch_sub(1);
        }).detach();
    }

    close_db();
    closesocket(ListenSocket);
    WSACleanup();
    return 0;
}
