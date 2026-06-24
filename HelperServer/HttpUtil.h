#pragma once
#include "Common.h"

void send_response(
    SOCKET client_socket,
    int status_code,
    const std::string& status_text,
    const std::string& body,
    const std::string& content_type = "text/plain"
);
bool send_all(SOCKET client_socket, const char* data, size_t length);
void close_client(SOCKET client_socket);
std::string make_random_token(size_t bytes = 32);
const std::string& get_session_token();
bool request_has_valid_session(const std::string& request_data);
bool require_valid_session(SOCKET client_socket, const std::string& request_data);
bool request_has_allowed_host(const std::string& request_data);
bool require_allowed_host(SOCKET client_socket, const std::string& request_data);
std::string redact_sensitive(const std::string& value);
