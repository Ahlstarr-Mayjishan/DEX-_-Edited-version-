#include "HttpUtil.h"

#include <iomanip>
#include <random>
#include <regex>

namespace {

std::string lower_header_copy(const std::string& value) {
    std::string out = value;
    std::transform(out.begin(), out.end(), out.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return out;
}

std::string trim_header_copy(const std::string& value) {
    size_t start = 0;
    while (start < value.size() && std::isspace(static_cast<unsigned char>(value[start]))) start++;
    size_t end = value.size();
    while (end > start && std::isspace(static_cast<unsigned char>(value[end - 1]))) end--;
    return value.substr(start, end - start);
}

std::string get_header_value(const std::string& request_data, const std::string& header_name) {
    std::string lower_request = lower_header_copy(request_data);
    std::string lower_name = lower_header_copy(header_name);
    size_t pos = lower_request.find(lower_name);
    if (pos == std::string::npos) return "";
    size_t value_start = pos + header_name.size();
    size_t value_end = request_data.find("\r\n", value_start);
    if (value_end == std::string::npos) value_end = request_data.size();
    return trim_header_copy(request_data.substr(value_start, value_end - value_start));
}

} // namespace

bool send_all(SOCKET client_socket, const char* data, size_t length) {
    size_t total_sent = 0;
    while (total_sent < length) {
        size_t remaining = length - total_sent;
        int chunk = static_cast<int>(std::min<size_t>(remaining, INT_MAX));
        int sent = send(client_socket, data + total_sent, chunk, 0);
        if (sent == SOCKET_ERROR || sent == 0) {
            return false;
        }
        total_sent += static_cast<size_t>(sent);
    }
    return true;
}

void send_response(
    SOCKET client_socket,
    int status_code,
    const std::string& status_text,
    const std::string& body,
    const std::string& content_type
) {
    const std::string default_origin = std::string("http://localhost:") + DEFAULT_PORT;
    std::stringstream response;
    response << "HTTP/1.1 " << status_code << " " << status_text << "\r\n"
             << "Content-Type: " << content_type << "\r\n"
             << "Content-Length: " << body.length() << "\r\n"
             << "Access-Control-Allow-Origin: " << default_origin << "\r\n"
             << "Access-Control-Allow-Headers: Content-Type, X-Place-ID, X-MCP-Client, X-DEX-Session\r\n"
             << "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
             << "Connection: close\r\n\r\n"
             << body;

    std::string response_str = response.str();
    send_all(client_socket, response_str.c_str(), response_str.length());
}

void close_client(SOCKET client_socket) {
    shutdown(client_socket, SD_SEND);
    closesocket(client_socket);
}

std::string make_random_token(size_t bytes) {
    std::random_device rd;
    std::uniform_int_distribution<int> dist(0, 255);
    std::ostringstream out;
    out << std::hex << std::setfill('0');
    for (size_t i = 0; i < bytes; ++i) {
        out << std::setw(2) << dist(rd);
    }
    return out.str();
}

const std::string& get_session_token() {
    static const std::string token = make_random_token();
    return token;
}

bool request_has_valid_session(const std::string& request_data) {
    std::string token = get_header_value(request_data, "X-DEX-Session:");
    if (token.empty()) {
        size_t line_end = request_data.find("\r\n");
        std::string request_line = request_data.substr(0, line_end == std::string::npos ? request_data.size() : line_end);
        size_t session_pos = request_line.find("session=");
        if (session_pos != std::string::npos) {
            size_t value_start = session_pos + 8;
            size_t value_end = request_line.find_first_of("& #\r\n", value_start);
            token = request_line.substr(value_start, value_end == std::string::npos ? std::string::npos : value_end - value_start);
        }
    }
    return !token.empty() && token == get_session_token();
}

bool require_valid_session(SOCKET client_socket, const std::string& request_data) {
    if (request_has_valid_session(request_data)) {
        return true;
    }
    send_response(client_socket, 403, "Forbidden", "{\"ok\":false,\"error\":\"missing or invalid DEX session token\"}", "application/json");
    return false;
}

bool request_has_allowed_host(const std::string& request_data) {
    std::string host = lower_header_copy(get_header_value(request_data, "Host:"));
    if (host.empty()) {
        return true;
    }
    const std::string port = DEFAULT_PORT;
    return host == "localhost:" + port
        || host == "127.0.0.1:" + port
        || host == "[::1]:" + port
        || host == "localhost"
        || host == "127.0.0.1"
        || host == "[::1]";
}

bool require_allowed_host(SOCKET client_socket, const std::string& request_data) {
    if (request_has_allowed_host(request_data)) {
        return true;
    }
    send_response(client_socket, 403, "Forbidden", "{\"ok\":false,\"error\":\"invalid Host header\"}", "application/json");
    return false;
}

std::string redact_sensitive(const std::string& value) {
    std::string out = value;
    const std::pair<std::regex, std::string> rules[] = {
        {std::regex(R"((\.ROBLOSECURITY\s*[=:]\s*)[^\s;,"']+)", std::regex_constants::icase), "$1[REDACTED]"},
        {std::regex(R"((Authorization\s*:\s*Bearer\s+)[A-Za-z0-9._~+/=-]+)", std::regex_constants::icase), "$1[REDACTED]"},
        {std::regex(R"((Bearer\s+)[A-Za-z0-9._~+/=-]+)", std::regex_constants::icase), "$1[REDACTED]"},
        {std::regex(R"((x-api-key\s*[:=]\s*)[A-Za-z0-9._~+/=-]+)", std::regex_constants::icase), "$1[REDACTED]"},
        {std::regex(R"(gh[pousr]_[A-Za-z0-9_]{20,})"), "[REDACTED_GITHUB_TOKEN]"},
        {std::regex(R"(sk-[A-Za-z0-9_-]{20,})"), "[REDACTED_OPENAI_KEY]"},
        {std::regex(R"(AIza[0-9A-Za-z_-]{20,})"), "[REDACTED_GOOGLE_KEY]"},
    };
    for (const auto& rule : rules) {
        out = std::regex_replace(out, rule.first, rule.second);
    }
    return out;
}
