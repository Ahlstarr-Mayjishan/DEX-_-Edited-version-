#pragma once
#include <string>
#include <vector>

struct ASTWarning {
    std::string type;     // e.g. "DeadCode", "UnusedVariable", "Obfuscation"
    std::string message;  // Detailed warning message
    int line;            // Approx line number
};

struct ASTAnalysisResult {
    bool ok = false;
    std::vector<ASTWarning> warnings;
    int function_count = 0;
    int local_count = 0;
    int global_count = 0;
    int statement_count = 0;
    int line_count = 0;
};

std::string ast_analyze_source(const std::string& source);
