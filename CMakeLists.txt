#
#  Copyright (c) 2018-2023, Intel Corporation
#
#  SPDX-License-Identifier: BSD-3-Clause

#
# ispc examples: mandelbrot
#
cmake_minimum_required(VERSION 3.12)

set (PROJECT_NAME dist1ll_ispc)
project(${PROJECT_NAME} C CXX)

if(CMAKE_BUILD_TYPE)
    # Validate build type
    set(CONFIGURATION_TYPES "Debug;Release;RelWithDebInfo")

    string(FIND "${CONFIGURATION_TYPES}" "${CMAKE_BUILD_TYPE}" MATCHED_CONFIG)
    if (${MATCHED_CONFIG} EQUAL -1)
        message(FATAL_ERROR "CMAKE_BUILD_TYPE (${CMAKE_BUILD_TYPE}) allows only the following values: ${CONFIGURATION_TYPES}")
    endif()
else(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release")
    message(STATUS "Build type not specified: Use Release by default.")
endif(CMAKE_BUILD_TYPE)


if (UNIX)
    if(NOT ISPC_ARCH)
        execute_process( COMMAND sh "-c" "uname -m | sed -e s/x86_64/x86/ -e s/amd64/x86/ -e s/i686/x86/ -e s/arm64/aarch64/ -e s/arm.*/arm/ -e s/sa110/arm/" OUTPUT_VARIABLE ARCH)
        string(STRIP ${ARCH} ARCH)
        execute_process( COMMAND getconf LONG_BIT OUTPUT_VARIABLE ARCH_BIT)
        string(STRIP ${ARCH_BIT} arch_bit)
        if ("${ARCH}" STREQUAL "x86")
            if (${arch_bit} EQUAL 32)
                set(ispc_arch "x86")
            else()
                set(ispc_arch "x86-64")
            endif()
        elseif ("${ARCH}" STREQUAL "arm")
            set(ispc_arch "arm")
        elseif ("${ARCH}" STREQUAL "aarch64")
            set(ispc_arch "aarch64")
        endif()
    endif()
    set(ISPC_ARCH "${ispc_arch}" CACHE STRING "ISPC CPU ARCH")
    set(ISPC_ARCH_BIT "${arch_bit}" CACHE STRING "ISPC CPU BIT")
else()
    if(NOT ISPC_ARCH)
        set(ispc_arch "x86")
        if (CMAKE_SIZEOF_VOID_P EQUAL 8 )
            set(ispc_arch "x86-64")
        endif()
    endif()

    set(ISPC_ARCH "${ispc_arch}" CACHE STRING "ISPC CPU ARCH")
    set(ISPC_ARCH_BIT "${arch_bit}" CACHE STRING "ISPC CPU BIT")
endif()

enable_language(ISPC)

function(add_ispc_example)
    set(options USE_COMMON_SETTINGS)
    set(oneValueArgs NAME ISPC_SRC_NAME DATA_DIR)
    set(multiValueArgs ISPC_IA_TARGETS ISPC_ARM_TARGETS ISPC_FLAGS TARGET_SOURCES LIBRARIES DATA_FILES)
    cmake_parse_arguments("example" "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

    if ("${ISPC_ARCH}" MATCHES "x86")
        string(REPLACE "," ";" ISPC_TARGETS ${example_ISPC_IA_TARGETS})
    elseif ("${ISPC_ARCH}" STREQUAL "arm" OR "${ISPC_ARCH}" STREQUAL "aarch64")
        string(REPLACE "," ";" ISPC_TARGETS ${example_ISPC_ARM_TARGETS})
    else()
        message(FATAL_ERROR "Unknown architecture ${ISPC_ARCH}")
    endif()

    add_executable(${example_NAME})
    target_sources(${example_NAME}
        PRIVATE
            "${CMAKE_CURRENT_SOURCE_DIR}/${ISPC_SRC_NAME}.ispc"
            ${example_TARGET_SOURCES}
        )

    # Set C++ standard to C++11.
    set_target_properties(${example_NAME} PROPERTIES
        CXX_STANDARD 11
        CXX_STANDARD_REQUIRED YES)

    set_property(TARGET ${example_NAME} PROPERTY POSITION_INDEPENDENT_CODE ON)
    set_property(TARGET ${example_NAME} PROPERTY ISPC_INSTRUCTION_SETS "${ISPC_TARGETS}")
    target_compile_options(${example_NAME} PRIVATE $<$<COMPILE_LANGUAGE:ISPC>:${example_ISPC_FLAGS}>)
    target_compile_options(${example_NAME} PRIVATE $<$<COMPILE_LANGUAGE:ISPC>:--arch=${ISPC_ARCH}>)

    if (UNIX)
        set(arch_flag "-m${ISPC_ARCH_BIT}")
        target_compile_options(${example_NAME} PRIVATE $<$<COMPILE_LANGUAGE:C,CXX>:${arch_flag}>)
    elseif (WIN32 AND MSVC)
        target_compile_options(${example_NAME} PRIVATE  $<$<COMPILE_LANGUAGE:C,CXX>:/fp:fast /Oi>)
    endif()

    # Link libraries
    if (example_LIBRARIES)
        target_link_libraries(${example_NAME} ${example_LIBRARIES})
    endif()

    set_target_properties(${example_NAME} PROPERTIES FOLDER "Examples")
    if(MSVC)
        # Group ISPC files inside Visual Studio
        source_group("ISPC" FILES "${CMAKE_CURRENT_SOURCE_DIR}/${ISPC_SRC_NAME}.ispc")
    endif()

endfunction()

if(WIN32)
    add_compile_definitions(WIN32)
    if(MSVC)
        add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/EHsc>)
    endif()
endif()

if (NOT DEFINED ISPC_EXECUTABLE)
    find_program (ISPC_EXECUTABLE ispc)
    if (NOT ISPC_EXECUTABLE)
        message(FATAL_ERROR "Failed to find ispc" )
    endif()
endif()

set (ISPC_SRC_NAME "csv")
set (TARGET_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp)
set (ISPC_IA_TARGETS "sse2-i32x4,sse4-i32x8,avx1-i32x16,avx2-i32x16,avx512knl-x16,avx512skx-x16" CACHE STRING "ISPC IA targets")
set (ISPC_ARM_TARGETS "neon" CACHE STRING "ISPC ARM targets")
add_ispc_example(NAME "csv"
              ISPC_IA_TARGETS ${ISPC_IA_TARGETS}
              ISPC_ARM_TARGETS ${ISPC_ARM_TARGETS}
              ISPC_SRC_NAME ${ISPC_SRC_NAME}
              TARGET_SOURCES ${TARGET_SOURCES}
              USE_COMMON_SETTINGS)
