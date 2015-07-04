include(ExternalProject)

set(LUAJIT_DIR "${CMAKE_CURRENT_BINARY_DIR}/luajit")
set(LUAJIT_LIB "${LUAJIT_DIR}/lib/libluajit-5.1.a")
set(LUAJIT_BIN "${LUAJIT_DIR}/bin/luajit")
set(LUAJIT_INC "${LUAJIT_DIR}/include/luajit-2.1")
set(LUAJIT_HASH 28d8728)

externalproject_add(luajit_project
	GIT_REPOSITORY http://luajit.org/git/luajit-2.0.git
	GIT_TAG ${LUAJIT_HASH}
	PREFIX "${CMAKE_CURRENT_BINARY_DIR}/luajit_project"
	CONFIGURE_COMMAND ""
	UPDATE_COMMAND ""
	BUILD_COMMAND make
		XCFLAGS=-DLUAJIT_ENABLE_LUA52COMPAT
		BUILDMODE=static
		INSTALL_TNAME=luajit
		amalg
	INSTALL_COMMAND make
		XCFLAGS=-DLUAJIT_ENABLE_LUA52COMPAT
		BUILDMODE=static
		INSTALL_TNAME=luajit
		PREFIX=${LUAJIT_DIR}
		install
	BUILD_IN_SOURCE 1
)

add_library(libluajit STATIC IMPORTED)
set_target_properties(libluajit PROPERTIES IMPORTED_LOCATION ${LUAJIT_LIB})
add_dependencies(libluajit luajit_project)

add_executable(luajit IMPORTED)
set_target_properties(luajit PROPERTIES IMPORTED_LOCATION ${LUAJIT_BIN})
add_dependencies(luajit luajit_project)

