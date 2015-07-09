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
	set(CMAKE_EXE_LINKER_FLAGS " -pagezero_size 10000 -image_base 100000000 -Wl,-export_dynamic")
else()
	message(FATAL_ERROR "platform not supported yet: ${CMAKE_SYSTEM_NAME}")
endif()

include(cmake/Siphon.cmake)
include(cmake/LuaJIT.cmake)

include_directories(BEFORE src ${SIPHON_INC} ${LUAJIT_INC})
include_directories(AFTER ${CMAKE_CURRENT_BINARY_DIR})

add_custom_command(
	OUTPUT
		${PROJECT_SOURCE_DIR}/levee_cdef.h
	COMMAND
	luajit ${PROJECT_SOURCE_DIR}/cdef/manifest.lua ${CMAKE_CURRENT_BINARY_DIR}/levee_cdef.h
	DEPENDS
		${PROJECT_SOURCE_DIR}/cdef/manifest.lua
	VERBATIM
)

add_custom_command(
	OUTPUT
		${CMAKE_CURRENT_BINARY_DIR}/liblevee.c
	COMMAND 
		luajit ${PROJECT_SOURCE_DIR}/bin/bundle.lua ${CMAKE_CURRENT_BINARY_DIR}/liblevee.c ${PROJECT_SOURCE_DIR} levee
	DEPENDS
		${PROJECT_SOURCE_DIR}/bin/bundle.lua
		${PROJECT_SOURCE_DIR}/levee_cdef.h
	VERBATIM
)

add_executable(
	levee
	src/chan.c
	src/heap.c
	src/levee.c
	src/list.c
	src/main.c
	${CMAKE_CURRENT_BINARY_DIR}/liblevee.c
)

add_dependencies(levee luajit)
target_link_libraries(levee libsiphon libluajit)

