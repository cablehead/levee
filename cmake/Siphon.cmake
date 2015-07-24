include(ExternalProject)

set(SIPHON_DIR "${CMAKE_CURRENT_BINARY_DIR}/siphon")
set(SIPHON_LIB "${SIPHON_DIR}/lib/libsiphon.a")
set(SIPHON_INC "${SIPHON_DIR}/include")
set(SIPHON_HASH 53be2e5)

externalproject_add(siphon_project
	GIT_REPOSITORY git@github.com:imgix/siphon.git
	GIT_TAG ${SIPHON_HASH}
	PREFIX "${CMAKE_CURRENT_BINARY_DIR}/siphon_project_${SIPHON_HASH}"
	UPDATE_COMMAND ""
	CMAKE_ARGS
		"-G${CMAKE_GENERATOR}"
		"-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
		"-DCMAKE_INSTALL_PREFIX=${SIPHON_DIR}"
)

add_library(libsiphon STATIC IMPORTED)
set_target_properties(libsiphon PROPERTIES IMPORTED_LOCATION ${SIPHON_LIB})
add_dependencies(libsiphon siphon_project)
