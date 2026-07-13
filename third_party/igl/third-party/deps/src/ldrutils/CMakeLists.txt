cmake_minimum_required(VERSION 3.22)

project("LUtils" CXX C)

include(cmake/findavx2.cmake)

LMATH_CHECK_FOR_AVX2()

if(NOT HAVE_AVX)
	set(LMATH_ENABLE_AVX OFF CACHE BOOL "")
endif()

if(NOT HAVE_AVX2)
	set(LMATH_ENABLE_AVX2 OFF CACHE BOOL "")
endif()

option(LMATH_USE_SHORTCUT_TYPES "Use lmath vector types without the namespace" OFF)
option(LMATH_ENABLE_TESTS "Enable tests" OFF)
option(LMATH_ENABLE_AVX   "Enable AVX"    ON)
option(LMATH_ENABLE_AVX2  "Enable AVX2"   ON)

file(GLOB SRC_FILES LIST_DIRECTORIES false RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} lutils/*.cpp lmath/*.cpp)
file(GLOB HEADER_FILES LIST_DIRECTORIES false RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} lutils/*.h lmath/*.h)

add_library(LUtils ${SRC_FILES} ${HEADER_FILES})

target_include_directories(LUtils PUBLIC .)

set_property(TARGET LUtils PROPERTY CXX_STANDARD 20)
set_property(TARGET LUtils PROPERTY CXX_STANDARD_REQUIRED ON)

if(LMATH_USE_SHORTCUT_TYPES)
	target_compile_definitions(LUtils PUBLIC LMATH_USE_SHORTCUT_TYPES=1)
endif()

if(LMATH_ENABLE_AVX2)
	if(MSVC)
		target_compile_options(LUtils PUBLIC /arch:AVX2)
	else()
		target_compile_options(LUtils PUBLIC -mavx2)
	endif()
elseif(LMATH_ENABLE_AVX)
	if(MSVC)
		target_compile_options(LUtils PUBLIC /arch:AVX)
	else()
		target_compile_options(LUtils PUBLIC -mavx)
	endif()
endif()

if(LMATH_ENABLE_TESTS)
	set(BUILD_GMOCK    OFF CACHE BOOL "")
	set(INSTALL_GTEST  OFF CACHE BOOL "")
	set(GTEST_HAS_ABSL OFF CACHE BOOL "")
	add_subdirectory(tests/gtest "gtest")

	add_executable(lmath_tests tests/lmathTests.cpp)
	target_link_libraries(lmath_tests PUBLIC LUtils)
	target_link_libraries(lmath_tests PUBLIC gtest)
	target_link_libraries(lmath_tests PUBLIC gtest_main)
	target_compile_definitions(lmath_tests PUBLIC LMATH_USE_SHORTCUT_TYPES=1)
	enable_testing()
	add_test(NAME lmath_tests COMMAND lmath_tests)
endif()
