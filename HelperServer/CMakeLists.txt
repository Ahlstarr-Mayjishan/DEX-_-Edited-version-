cmake_minimum_required(VERSION 3.24)

project(DEXHelperServer LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(DEX_Helper
    main.cpp
    Auth.cpp
    SecureStore.cpp
    WsProtocol.cpp
    HttpUtil.cpp
    Routes.cpp
    Dashboard.cpp
    Win32App.cpp
    Index.cpp
    Toolchain.cpp
    Decompiler.cpp
    AST.cpp
    sqlite3.c
)

target_compile_definitions(DEX_Helper PRIVATE
    SQLITE_ENABLE_FTS5
)

target_include_directories(DEX_Helper PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(DEX_Helper PRIVATE
    ws2_32
    shell32
    gdi32
    wininet
    crypt32
)

if(MINGW)
    target_compile_options(DEX_Helper PRIVATE
        $<$<CONFIG:Release>:-O3>
    )
endif()

set_target_properties(DEX_Helper PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}"
)
