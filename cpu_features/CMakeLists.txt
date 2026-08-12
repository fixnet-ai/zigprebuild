cmake_minimum_required(VERSION 3.16)
message(STATUS "CMake version: ${CMAKE_VERSION}")


project(cpu_model C)

set(SRC_LIST
    ./cpu_model/cpu_model.h
)

message(STATUS "CMake system processor: ${CMAKE_SYSTEM_PROCESSOR}")

if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
    message(STATUS "Target architecture: x86_64")
    list(APPEND SRC_LIST ./cpu_model/x86.c)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "AMD64")
    message(STATUS "Target architecture: AMD64")
    list(APPEND SRC_LIST ./cpu_model/x86.c)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    message(STATUS "Target architecture: aarch64")
    list(APPEND SRC_LIST ./cpu_model/aarch64.c)
else()
    message(STATUS "Unknown target architecture")
endif()

add_library(cpu_model STATIC ${SRC_LIST})