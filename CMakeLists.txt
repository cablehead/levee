cmake_minimum_required(VERSION 2.8)
project(levee C)

set(CMAKE_C_FLAGS "-std=c99 -Wall -Wextra -Werror -pedantic")
set(CMAKE_C_FLAGS_DEBUG "-g")
set(CMAKE_C_FLAGS_RELEASE "-O2 -fomit-frame-pointer -march=native")
if(${CMAKE_SYSTEM_NAME} MATCHES "Linux")
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_BSD_SOURCE -D_GNU_SOURCE")
	set(CMAKE_EXE_LINKER_FLAGS "-pthread -Wl,--export-dynamic -static-libgcc")
	target_link_libraries(levee m dl)
elseif(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
	set(CMAKE_EXE_LINKER_FLAGS "-pagezero_size 10000 -image_base 100000000 -Wl,-export_dynamic")
else()
	message(FATAL_ERROR "platform not supported yet: ${CMAKE_SYSTEM_NAME}")
endif()

include(cmake/Siphon.cmake)
include(cmake/LuaJIT.cmake)
include(cmake/Levee.cmake)

include_directories(BEFORE
	${LEVEE_INC}
	${SIPHON_INC}
	${LUAJIT_INC}
	${CMAKE_CURRENT_BINARY_DIR}
)

add_executable(
	levee
	src/main.c
)

if("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
	set(LEVEE_LIB -Wl,--whole-archive,${LEVEE_LIB},--no-whole-archive)
elseif("${CMAKE_SYSTEM_NAME}" MATCHES "Darwin")
	set(LEVEE_LIB -Wl,-force_load,${LEVEE_LIB})
endif()

add_dependencies(levee liblevee)
target_link_libraries(levee ${LEVEE_LIB})

