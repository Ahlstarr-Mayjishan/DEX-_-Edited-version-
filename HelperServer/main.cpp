#ifndef UNICODE
#define UNICODE
#endif

#define WIN32_LEAN_AND_MEAN

#include <winsock2.h>
#include <ws2tcpip.h>
#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <fstream>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <cctype>

// Link with ws2_32.lib
#pragma comment(lib, "ws2_32.lib")

#define DEFAULT_PORT "8080"
#define BUFFER_SIZE 8192

// Fast C++ linear-time variable normalizer
std::string deobfuscate(const std::string& source) {
    std::unordered_map<std::string, std::string> var_map;
    int var_counter = 0;

    auto is_obfuscated = [](const std::string& name) {
        // Skip keywords
        static const std::unordered_set<std::string> reserved = {
            "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
            "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
            "until", "while", "self", "game", "workspace", "script"
        };
        if (reserved.count(name)) return false;

        // Match l__u__\d+ or u_\d+
        if (name.rfind("l__u__", 0) == 0 || name.rfind("u_", 0) == 0) return true;

        // Match _0x...
        if (name.rfind("_0x", 0) == 0 || name.rfind("0x", 0) == 0) return true;

        // Match barcode (composed only of I, l, 1 and length >= 4)
        if (name.length() >= 4) {
            bool barcode = true;
            for (char c : name) {
                if (c != 'I' && c != 'l' && c != '1') {
                    barcode = false;
                    break;
                }
            }
            if (barcode) return true;
        }
        return false;
    };

    // First pass: identify all obfuscated variable tokens
    std::string current_word = "";
    for (char c : source) {
        if (isalnum(static_cast<unsigned char>(c)) || c == '_') {
            current_word += c;
        } else {
            if (!current_word.empty()) {
                if (is_obfuscated(current_word) && var_map.count(current_word) == 0) {
                    var_map[current_word] = "var_" + std::to_string(++var_counter);
                }
                current_word = "";
            }
        }
    }
    if (!current_word.empty() && is_obfuscated(current_word) && var_map.count(current_word) == 0) {
        var_map[current_word] = "var_" + std::to_string(++var_counter);
    }

    // Second pass: reconstruct string with normalized variables
    std::string result = "";
    current_word = "";
    for (char c : source) {
        if (isalnum(static_cast<unsigned char>(c)) || c == '_') {
            current_word += c;
        } else {
            if (!current_word.empty()) {
                if (var_map.count(current_word)) {
                    result += var_map[current_word];
                } else {
                    result += current_word;
                }
                current_word = "";
            }
            result += c;
        }
    }
    if (!current_word.empty()) {
        if (var_map.count(current_word)) {
            result += var_map[current_word];
        } else {
            result += current_word;
        }
    }

    return result;
}

// Send HTTP response helper
void send_response(SOCKET client_socket, int status_code, const std::string& status_text, const std::string& body) {
    std::stringstream response;
    response << "HTTP/1.1 " << status_code << " " << status_text << "\r\n"
             << "Content-Type: text/plain\r\n"
             << "Content-Length: " << body.length() << "\r\n"
             << "Access-Control-Allow-Origin: *\r\n"
             << "Access-Control-Allow-Headers: *\r\n"
             << "Connection: close\r\n\r\n"
             << body;

    std::string response_str = response.str();
    send(client_socket, response_str.c_str(), static_cast<int>(response_str.length()), 0);
}

int main() {
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
        return 1;
    }

    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    hints.ai_flags = AI_PASSIVE;

    // Resolve the server address and port
    iResult = getaddrinfo(NULL, DEFAULT_PORT, &hints, &result);
    if (iResult != 0) {
        std::cerr << "getaddrinfo failed with error: " << iResult << std::endl;
        WSACleanup();
        return 1;
    }

    // Create a SOCKET for the server to listen for client connections
    ListenSocket = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
    if (ListenSocket == INVALID_SOCKET) {
        std::cerr << "socket failed with error: " << WSAGetLastError() << std::endl;
        freeaddrinfo(result);
        WSACleanup();
        return 1;
    }

    // Setup the TCP listening socket
    iResult = bind(ListenSocket, result->ai_addr, static_cast<int>(result->ai_addrlen));
    if (iResult == SOCKET_ERROR) {
        std::cerr << "bind failed with error: " << WSAGetLastError() << std::endl;
        freeaddrinfo(result);
        closesocket(ListenSocket);
        WSACleanup();
        return 1;
    }

    freeaddrinfo(result);

    iResult = listen(ListenSocket, SOMAXCONN);
    if (iResult == SOCKET_ERROR) {
        std::cerr << "listen failed with error: " << WSAGetLastError() << std::endl;
        closesocket(ListenSocket);
        WSACleanup();
        return 1;
    }

    std::cout << "DEX++ C++ Local Helper Server listening on port " << DEFAULT_PORT << "..." << std::endl;

    while (true) {
        // Accept a client socket
        ClientSocket = accept(ListenSocket, NULL, NULL);
        if (ClientSocket == INVALID_SOCKET) {
            std::cerr << "accept failed with error: " << WSAGetLastError() << std::endl;
            continue;
        }

        std::vector<char> recvbuf(BUFFER_SIZE);
        std::string request_data = "";
        int bytes_received;

        // Receive request data
        bytes_received = recv(ClientSocket, recvbuf.data(), BUFFER_SIZE - 1, 0);
        if (bytes_received > 0) {
            recvbuf[bytes_received] = '\0';
            request_data.append(recvbuf.data(), bytes_received);

            // Simple HTTP request parsing
            std::stringstream ss(request_data);
            std::string method, path, protocol;
            ss >> method >> path >> protocol;

            // Find body if it's a POST request
            size_t header_end = request_data.find("\r\n\r\n");
            std::string body = "";
            if (header_end != std::string::npos) {
                body = request_data.substr(header_end + 4);
                
                // Read Content-Length header to verify if we need to receive more body bytes
                size_t cl_pos = request_data.find("Content-Length:");
                if (cl_pos != std::string::npos) {
                    size_t cl_end = request_data.find("\r\n", cl_pos);
                    if (cl_end != std::string::npos) {
                        std::string cl_str = request_data.substr(cl_pos + 15, cl_end - (cl_pos + 15));
                        // Trim spaces
                        cl_str.erase(0, cl_str.find_first_not_of(" \t"));
                        cl_str.erase(cl_str.find_last_not_of(" \t") + 1);
                        int content_len = std::stoi(cl_str);
                        
                        while (static_cast<int>(body.length()) < content_len) {
                            int extra = recv(ClientSocket, recvbuf.data(), BUFFER_SIZE - 1, 0);
                            if (extra <= 0) break;
                            recvbuf[extra] = '\0';
                            body.append(recvbuf.data(), extra);
                        }
                    }
                }
            }

            // Handle API routes
            if (method == "OPTIONS") {
                // CORS preflight response
                send_response(ClientSocket, 204, "No Content", "");
            } else if (path == "/status" && method == "GET") {
                send_response(ClientSocket, 200, "OK", "DEX++ C++ Helper Server Active");
            } else if (path == "/script" && method == "GET") {
                std::ifstream script_file("DEX++_compiled.luau");
                if (!script_file.is_open()) {
                    script_file.open("../DEX++_compiled.luau");
                }
                if (script_file.is_open()) {
                    std::stringstream buffer;
                    buffer << script_file.rdbuf();
                    script_file.close();
                    send_response(ClientSocket, 200, "OK", buffer.str());
                } else {
                    send_response(ClientSocket, 404, "Not Found", "-- Error: DEX++_compiled.luau not found on server.");
                }
            } else if (path == "/log" && method == "POST") {
                std::ofstream log_file("dex_server_logs.txt", std::ios::app);
                if (log_file.is_open()) {
                    log_file << body << std::endl;
                    log_file.close();
                }
                send_response(ClientSocket, 200, "OK", "Logged");
            } else if (path == "/deobfuscate" && method == "POST") {
                std::string deobf = deobfuscate(body);
                send_response(ClientSocket, 200, "OK", deobf);
            } else {
                send_response(ClientSocket, 404, "Not Found", "404 Route Not Found");
            }
        }

        // shutdown the connection since we're done
        shutdown(ClientSocket, SD_SEND);
        closesocket(ClientSocket);
    }

    closesocket(ListenSocket);
    WSACleanup();
    return 0;
}
