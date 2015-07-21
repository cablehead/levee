set(LEVEE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
set(LEVEE_LIB "${LEVEE_DIR}/liblevee.a")
set(LEVEE_INC "${PROJECT_SOURCE_DIR}/src")
set(LEVEEBASE_LIB "${LEVEE_DIR}/libleveebase.a")

set(LEVEE_CDEF_MANIFEST ${PROJECT_SOURCE_DIR}/cdef/manifest.lua)
set(LEVEE_CDEF_HEADER ${CMAKE_CURRENT_BINARY_DIR}/levee_cdef.h)
file(GLOB_RECURSE LEVEE_CDEF ${PROJECT_SOURCE_DIR}/cdef/*.h)

set(LEVEE_BUNDLE_SCRIPT ${PROJECT_SOURCE_DIR}/bin/bundle.lua)
set(LEVEE_BUNDLE_OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/bundle.c)
file(GLOB_RECURSE LEVEE_BUNDLE ${PROJECT_SOURCE_DIR}/levee/*.lua)

set(LEVEE_LIB_SCRIPT ${PROJECT_SOURCE_DIR}/bin/lib.sh)

add_custom_command(
	OUTPUT ${LEVEE_CDEF_HEADER}
	COMMAND luajit ${LEVEE_CDEF_MANIFEST} ${LEVEE_CDEF_HEADER}
	DEPENDS ${LEVEE_CDEF_MANIFEST} ${LEVEE_CDEF}
	VERBATIM
)

add_custom_command(
	OUTPUT ${LEVEE_BUNDLE_OUTPUT}
	COMMAND luajit ${LEVEE_BUNDLE_SCRIPT} ${LEVEE_BUNDLE_OUTPUT} levee
		${PROJECT_SOURCE_DIR} levee
	DEPENDS ${LEVEE_BUNDLE_SCRIPT} ${LEVEE_CDEF_HEADER} ${LEVEE_BUNDLE}
	VERBATIM
)

add_library(
	libleveebase
	STATIC
	src/chan.c
	src/heap.c
	src/levee.c
	src/list.c
	${LEVEE_BUNDLE_OUTPUT}
)
add_dependencies(libleveebase libluajit libsiphon)
set_target_properties(libleveebase PROPERTIES OUTPUT_NAME leveebase)

add_custom_target(
	liblevee ALL
	COMMAND ${LEVEE_LIB_SCRIPT} ${LEVEE_LIB} ${LEVEEBASE_LIB} ${LUAJIT_LIB} ${SIPHON_LIB}
	BYPRODUCTS ${LEVEE_LIB}
	DEPENDS libleveebase libluajit libsiphon
)