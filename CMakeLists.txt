cmake_minimum_required(VERSION 2.8)
project(levee C)

set(INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/include")

set(CMAKE_C_FLAGS "-std=c99 -Wall -Wextra -Werror -pedantic -I${INCLUDE_DIR}")
set(CMAKE_C_FLAGS_DEBUG "-g")
set(CMAKE_C_FLAGS_RELEASE "-O2 -fomit-frame-pointer -march=native")

include(cmake/Siphon.cmake)
include(cmake/LuaJIT.cmake)
include(cmake/Levee.cmake)

add_custom_target(
	liblevee_target
	COMMAND ${LEVEE_INC}/link.sh ${LEVEE_LIB} $<TARGET_FILE:libleveebase> ${LUAJIT_LIB} ${SIPHON_LIB}
)
add_dependencies(liblevee_target libleveebase libluajit libsiphon)

include_directories(BEFORE
	/usr/local/include
	${LEVEE_INC}
	${SIPHON_INC}
	${LUAJIT_INC}
	${CMAKE_CURRENT_BINARY_DIR}
)

add_executable(
	levee
	src/main.c
)

add_dependencies(levee libleveebase liblevee_target)
set_target_properties(levee PROPERTIES LINK_DEPENDS ${LEVEEBASE_LIB})

install(TARGETS levee RUNTIME DESTINATION bin)
install(FILES ${LEVEE_LIB} DESTINATION lib)
install(FILES
	src/chan.h
	src/heap.h
	src/levee.h
	src/list.h
	${LUAJIT_INC}/lauxlib.h
	${LUAJIT_INC}/lua.h
	${LUAJIT_INC}/lua.hpp
	${LUAJIT_INC}/luaconf.h
	${LUAJIT_INC}/luajit.h
	${LUAJIT_INC}/lualib.h
	DESTINATION include/levee
)

if("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_BSD_SOURCE -D_GNU_SOURCE")
	set(CMAKE_EXE_LINKER_FLAGS "-pthread -Wl,--export-dynamic -static-libgcc")
	target_link_libraries(levee m dl)
	target_link_libraries(levee -Wl,--whole-archive,${LEVEE_LIB},--no-whole-archive)
elseif("${CMAKE_SYSTEM_NAME}" MATCHES "Darwin")
	set(CMAKE_EXE_LINKER_FLAGS "-pagezero_size 10000 -image_base 100000000 -Wl,-export_dynamic")
	target_link_libraries(levee -Wl,-force_load,${LEVEE_LIB})
else()
	message(FATAL_ERROR "platform not supported yet: ${CMAKE_SYSTEM_NAME}")
endif()
