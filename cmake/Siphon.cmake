include(ExternalProject)

set(SIPHON_DIR "${CMAKE_CURRENT_BINARY_DIR}/siphon")
set(SIPHON_LIB "${SIPHON_DIR}/lib/libsiphon.a")
set(SIPHON_INC "${SIPHON_DIR}/include")

externalproject_add(siphon_project
	GIT_REPOSITORY git@github.com:imgix/siphon.git
	GIT_TAG 81f451f
	PREFIX "${CMAKE_CURRENT_BINARY_DIR}/siphon_project"
	UPDATE_COMMAND git pull origin master
	CMAKE_ARGS
		"-G${CMAKE_GENERATOR}"
		"-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
		"-DCMAKE_INSTALL_PREFIX=${SIPHON_DIR}"
)

if("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
	set(SIPHON_LIB -Wl,--whole-archive,${SIPHON_LIB},--no-whole-archive)
elseif("${CMAKE_SYSTEM_NAME}" MATCHES "Darwin")
	set(SIPHON_LIB -Wl,-force_load,${SIPHON_LIB})
endif()

add_library(libsiphon STATIC IMPORTED)
set_target_properties(libsiphon PROPERTIES IMPORTED_LOCATION ${SIPHON_LIB})
add_dependencies(libsiphon siphon_project)
