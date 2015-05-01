#include <stdio.h>
#include <assert.h>

// probably not the best to include luajit headers directly (use compiler
// flags)
#include <luajit-2.0/lua.h>
#include <luajit-2.0/lualib.h>
#include <luajit-2.0/lauxlib.h>


extern int
coro_yield (lua_State *L)
{
	lua_State **coro = (lua_State **) lua_topointer(L, 1);
	*coro = L;
	return lua_yield(L, lua_gettop(L) - 1);
}


extern int
coro_resume (lua_State *L)
{
	int n;

	lua_State *coro = *(lua_State **) lua_topointer(L, 1);
	n = lua_gettop(L) - 1;
	lua_xmove(L, coro, n);

	int rc = lua_resume(coro, n);
	// TODO: error handling
	assert(rc <= LUA_YIELD);

	n = lua_gettop(coro);
	lua_xmove(coro, L, n);
	return n;
}


static const struct luaL_Reg lib[] = {
	{"yield", coro_yield},
	{"resume", coro_resume},
	{NULL, NULL}
};

extern int
luaopen_coro (lua_State *L)
{
	luaL_register (L, "coro", lib);
	return 1;
}
