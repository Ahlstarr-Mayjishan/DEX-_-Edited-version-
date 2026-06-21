#include "AST.h"
#include <sstream>
#include <algorithm>
#include <unordered_set>
#include <unordered_map>
#include <iostream>

enum class TokenType {
    Keyword,
    Identifier,
    String,
    Number,
    Operator,
    Eof
};

struct Token {
    TokenType type;
    std::string value;
    int line;
};

// Simple lexical analyzer for Luau
std::vector<Token> tokenize_luau(const std::string& source, int& out_line_count) {
    std::vector<Token> tokens;
    int line = 1;
    size_t i = 0;
    size_t len = source.size();
    
    static const std::unordered_set<std::string> keywords = {
        "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
        "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
        "until", "while", "continue"
    };
    
    while (i < len) {
        char c = source[i];
        
        // Handle newlines
        if (c == '\n') {
            line++;
            i++;
            continue;
        }
        if (c == '\r') {
            if (i + 1 < len && source[i + 1] == '\n') {
                line++;
                i += 2;
            } else {
                line++;
                i++;
            }
            continue;
        }
        
        // Handle whitespace
        if (std::isspace(static_cast<unsigned char>(c))) {
            i++;
            continue;
        }
        
        // Handle comments
        if (c == '-' && i + 1 < len && source[i + 1] == '-') {
            i += 2;
            // Check for multi-line comment --[[
            if (i + 1 < len && source[i] == '[' && source[i + 1] == '[') {
                i += 2;
                while (i < len) {
                    if (source[i] == ']' && i + 1 < len && source[i + 1] == ']') {
                        i += 2;
                        break;
                    }
                    if (source[i] == '\n') line++;
                    else if (source[i] == '\r') {
                        if (i + 1 < len && source[i + 1] == '\n') { i++; }
                        line++;
                    }
                    i++;
                }
            } else {
                // Single line comment
                while (i < len && source[i] != '\n' && source[i] != '\r') {
                    i++;
                }
            }
            continue;
        }
        
        // Handle string literals
        if (c == '"' || c == '\'' || (c == '[' && i + 1 < len && source[i + 1] == '[')) {
            char quote = c;
            int start_line = line;
            std::string str_val = "";
            if (c == '[') { // Multi-line string [[ ... ]]
                i += 2;
                while (i < len) {
                    if (source[i] == ']' && i + 1 < len && source[i + 1] == ']') {
                        i += 2;
                        break;
                    }
                    if (source[i] == '\n') line++;
                    else if (source[i] == '\r') {
                        if (i + 1 < len && source[i + 1] == '\n') { i++; }
                        line++;
                    }
                    str_val += source[i];
                    i++;
                }
                tokens.push_back({TokenType::String, str_val, start_line});
            } else { // Single line string
                i++;
                while (i < len && source[i] != quote) {
                    if (source[i] == '\\' && i + 1 < len) {
                        str_val += source[i];
                        str_val += source[i + 1];
                        if (source[i + 1] == '\n') line++;
                        i += 2;
                    } else {
                        if (source[i] == '\n') line++;
                        str_val += source[i];
                        i++;
                    }
                }
                if (i < len) i++; // consume closing quote
                tokens.push_back({TokenType::String, str_val, start_line});
            }
            continue;
        }
        
        // Handle numbers
        if (std::isdigit(static_cast<unsigned char>(c)) || (c == '.' && i + 1 < len && std::isdigit(static_cast<unsigned char>(source[i + 1])))) {
            std::string num_val = "";
            bool hex = false;
            if (c == '0' && i + 1 < len && (source[i + 1] == 'x' || source[i + 1] == 'X')) {
                hex = true;
                num_val += "0x";
                i += 2;
            }
            while (i < len) {
                char nc = source[i];
                if (hex) {
                    if (std::isxdigit(static_cast<unsigned char>(nc)) || nc == '.') {
                        num_val += nc;
                        i++;
                    } else {
                        break;
                    }
                } else {
                    if (std::isdigit(static_cast<unsigned char>(nc)) || nc == '.' || nc == 'e' || nc == 'E' || nc == '+' || nc == '-') {
                        num_val += nc;
                        i++;
                    } else {
                        break;
                    }
                }
            }
            tokens.push_back({TokenType::Number, num_val, line});
            continue;
        }
        
        // Handle identifiers and keywords
        if (std::isalpha(static_cast<unsigned char>(c)) || c == '_') {
            std::string name = "";
            while (i < len && (std::isalnum(static_cast<unsigned char>(source[i])) || source[i] == '_')) {
                name += source[i];
                i++;
            }
            if (keywords.count(name)) {
                tokens.push_back({TokenType::Keyword, name, line});
            } else {
                tokens.push_back({TokenType::Identifier, name, line});
            }
            continue;
        }
        
        // Operators and punctuation
        std::string op = "";
        op += c;
        if (i + 1 < len) {
            char next = source[i + 1];
            if ((c == '=' || c == '<' || c == '>' || c == '~' || c == '+' || c == '-' || c == '*' || c == '/' || c == '%' || c == '^') && next == '=') {
                op += next;
                i++;
            } else if (c == '.' && next == '.') {
                op += next;
                i++;
                if (i + 1 < len && source[i + 1] == '.') {
                    op += '.';
                    i++;
                }
            } else if (c == ':' && next == ':') {
                op += next;
                i++;
            }
        }
        tokens.push_back({TokenType::Operator, op, line});
        i++;
    }
    
    out_line_count = line;
    return tokens;
}

struct LocalVar {
    std::string name;
    int declare_line;
    bool referenced = false;
};

struct Scope {
    std::vector<LocalVar> locals;
    bool has_returned = false;
};

std::string ast_analyze_source(const std::string& source) {
    ASTAnalysisResult result;
    int lines = 0;
    std::vector<Token> tokens = tokenize_luau(source, lines);
    result.line_count = lines;
    result.ok = true;
    
    std::vector<Scope> scope_stack;
    scope_stack.push_back(Scope()); // global scope
    
    size_t ti = 0;
    size_t count = tokens.size();
    
    // Check for common obfuscated string array indicators
    int hex_string_count = 0;
    int large_table_size = 0;
    
    while (ti < count) {
        const Token& tok = tokens[ti];
        result.statement_count++;
        
        // Scan for obfuscated naming patterns
        if (tok.type == TokenType::Identifier) {
            std::string val = tok.value;
            // Barcode check (e.g. lIlIIl, l1ll1l)
            if (val.size() >= 5) {
                bool barcode = true;
                for (char tc : val) {
                    if (tc != 'I' && tc != 'l' && tc != '1' && tc != '_') {
                        barcode = false;
                        break;
                    }
                }
                if (barcode) {
                    result.warnings.push_back({
                        "Obfuscation",
                        "Obfuscated variable naming pattern detected: '" + val + "'",
                        tok.line
                    });
                }
            }
        }
        
        if (tok.type == TokenType::String) {
            // Count strings that look like hex sequences
            std::string val = tok.value;
            if (val.size() >= 4 && val.find('\\') != std::string::npos) {
                hex_string_count++;
            }
        }
        
        // Process variables, block scopes, and returns
        if (tok.type == TokenType::Keyword) {
            if (tok.value == "local") {
                result.local_count++;
                if (ti + 1 < count) {
                    const Token& next = tokens[ti + 1];
                    if (next.type == TokenType::Keyword && next.value == "function") {
                        // local function name
                        if (ti + 2 < count && tokens[ti + 2].type == TokenType::Identifier) {
                            scope_stack.back().locals.push_back({tokens[ti + 2].value, tokens[ti + 2].line, false});
                            scope_stack.push_back(Scope()); // new function scope
                            ti += 2;
                        }
                    } else if (next.type == TokenType::Identifier) {
                        // local var1, var2 = ...
                        size_t decl_idx = ti + 1;
                        while (decl_idx < count) {
                            if (tokens[decl_idx].type == TokenType::Identifier) {
                                scope_stack.back().locals.push_back({tokens[decl_idx].value, tokens[decl_idx].line, false});
                            }
                            if (decl_idx + 1 < count && tokens[decl_idx + 1].type == TokenType::Operator && tokens[decl_idx + 1].value == ",") {
                                decl_idx += 2;
                            } else {
                                break;
                            }
                        }
                        ti = decl_idx;
                    }
                }
            } else if (tok.value == "function") {
                result.function_count++;
                scope_stack.push_back(Scope()); // enter function scope
                
                // Track function parameters if defined
                if (ti + 1 < count && tokens[ti + 1].type == TokenType::Identifier) {
                    ti++; // skip function name / identifier
                }
                if (ti + 1 < count && tokens[ti + 1].type == TokenType::Operator && tokens[ti + 1].value == "(") {
                    ti += 2;
                    while (ti < count) {
                        if (tokens[ti].type == TokenType::Operator && tokens[ti].value == ")") {
                            break;
                        }
                        if (tokens[ti].type == TokenType::Identifier) {
                            scope_stack.back().locals.push_back({tokens[ti].value, tokens[ti].line, false});
                        }
                        ti++;
                    }
                }
            } else if (tok.value == "if" || tok.value == "for" || tok.value == "while" || tok.value == "do" || tok.value == "repeat") {
                scope_stack.push_back(Scope()); // enter conditional/loop scope
            } else if (tok.value == "end" || tok.value == "until") {
                // Exit current scope
                if (scope_stack.size() > 1) {
                    Scope popped = scope_stack.back();
                    scope_stack.pop_back();
                    
                    // Check for unused local variables in the popped scope
                    for (const auto& local : popped.locals) {
                        if (!local.referenced) {
                            // Exclude common placeholder variable names like "_"
                            if (local.name != "_" && local.name != "unused" && local.name != "self") {
                                result.warnings.push_back({
                                    "UnusedVariable",
                                    "Local variable '" + local.name + "' was declared but never referenced.",
                                    local.declare_line
                                });
                            }
                        }
                    }
                }
            } else if (tok.value == "return" || tok.value == "break" || tok.value == "continue") {
                // Check if we are already marked returned (Dead code check)
                if (scope_stack.back().has_returned) {
                    result.warnings.push_back({
                        "DeadCode",
                        "Unreachable statement detected: statement following '" + tok.value + "' will never be executed.",
                        tok.line
                    });
                } else {
                    scope_stack.back().has_returned = true;
                }
            }
        } else if (tok.type == TokenType::Identifier) {
            // Check reference to variable in the scope stack
            std::string name = tok.value;
            
            // Check if this is a variable declaration vs a reference
            bool is_decl = false;
            if (ti > 0) {
                const Token& prev = tokens[ti - 1];
                if (prev.type == TokenType::Keyword && prev.value == "local") {
                    is_decl = true;
                } else if (prev.type == TokenType::Operator && prev.value == ",") {
                    // Check backwards to see if there is a 'local' keyword
                    size_t check_idx = ti - 1;
                    while (check_idx > 0 && tokens[check_idx].type == TokenType::Operator && tokens[check_idx].value == ",") {
                        if (check_idx >= 2 && tokens[check_idx - 1].type == TokenType::Identifier) {
                            check_idx -= 2;
                        } else {
                            break;
                        }
                    }
                    if (check_idx > 0 && tokens[check_idx - 1].type == TokenType::Keyword && tokens[check_idx - 1].value == "local") {
                        is_decl = true;
                    }
                }
            }
            
            if (!is_decl) {
                // Mark variable as referenced
                bool found = false;
                for (int s = static_cast<int>(scope_stack.size()) - 1; s >= 0; s--) {
                    for (auto& local : scope_stack[s].locals) {
                        if (local.name == name) {
                            local.referenced = true;
                            found = true;
                            break;
                        }
                    }
                    if (found) break;
                }
                if (!found) {
                    result.global_count++;
                }
            }
            
            // If we have returned in this scope block, any active code is unreachable
            if (scope_stack.back().has_returned) {
                result.warnings.push_back({
                    "DeadCode",
                    "Unreachable expression/statement: '" + name + "' will never execute.",
                    tok.line
                });
            }
        } else if (tok.type == TokenType::Operator) {
            // If we have returned, operators represent dead code
            if (scope_stack.back().has_returned && tok.value != "end" && tok.value != "else" && tok.value != "elseif" && tok.value != "until") {
                // Ensure we don't trigger warnings for punctuation inside blocks
                if (tok.value != ";" && tok.value != "," && tok.value != "}" && tok.value != ")") {
                    result.warnings.push_back({
                        "DeadCode",
                        "Unreachable operator expression: '" + tok.value + "' will never execute.",
                        tok.line
                    });
                }
            }
        }
        
        ti++;
    }
    
    // Check remaining scopes
    while (scope_stack.size() > 1) {
        Scope popped = scope_stack.back();
        scope_stack.pop_back();
        for (const auto& local : popped.locals) {
            if (!local.referenced && local.name != "_" && local.name != "unused" && local.name != "self") {
                result.warnings.push_back({
                    "UnusedVariable",
                    "Local variable '" + local.name + "' was declared but never referenced.",
                    local.declare_line
                });
            }
        }
    }
    
    // Check for high density of hex strings (obfuscation signature)
    if (hex_string_count > 15) {
        result.warnings.push_back({
            "Obfuscation",
            "High concentration of hex-encoded string literals detected (possible script packaging/obfuscation). Count: " + std::to_string(hex_string_count),
            1
        });
    }
    
    // Sort warnings by line number and remove duplicates
    std::sort(result.warnings.begin(), result.warnings.end(), [](const ASTWarning& a, const ASTWarning& b) {
        if (a.line == b.line) return a.message < b.message;
        return a.line < b.line;
    });
    result.warnings.erase(std::unique(result.warnings.begin(), result.warnings.end(), [](const ASTWarning& a, const ASTWarning& b) {
        return a.line == b.line && a.type == b.type && a.message == b.message;
    }), result.warnings.end());
    
    // Convert results to JSON
    std::stringstream json;
    json << "{";
    json << "\"ok\":" << (result.ok ? "true" : "false") << ",";
    json << "\"bytes\":" << source.size() << ",";
    json << "\"lines\":" << result.line_count << ",";
    json << "\"functions\":" << result.function_count << ",";
    json << "\"locals\":" << result.local_count << ",";
    json << "\"globals\":" << result.global_count << ",";
    json << "\"statements\":" << result.statement_count << ",";
    json << "\"warnings\":[";
    bool first = true;
    for (const auto& w : result.warnings) {
        if (!first) json << ",";
        first = false;
        
        // Escape JSON message
        std::string esc_msg = "";
        for (char wc : w.message) {
            if (wc == '"') esc_msg += "\\\"";
            else if (wc == '\\') esc_msg += "\\\\";
            else if (wc == '\n') esc_msg += "\\n";
            else if (wc == '\r') esc_msg += "\\r";
            else esc_msg += wc;
        }
        
        json << "{\"type\":\"" << w.type << "\",\"message\":\"" << esc_msg << "\",\"line\":" << w.line << "}";
    }
    json << "]";
    json << "}";
    
    return json.str();
}
