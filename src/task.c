#include <assert.h>

#include "task.h"

static int
task_yield (lua_State *L)
{
	lua_State **task = (lua_State **) lua_topointer(L, 1);
	*task = L;
	return lua_yield(L, lua_gettop(L) - 1);
}


static int
task_resume (lua_State *L)
{
	int n;

	lua_State *task = *(lua_State **) lua_topointer(L, 1);
	n = lua_gettop(L);
	lua_xmove(L, task, n - 1);

	int rc = lua_resume(task, n - 1);
	// TODO: error handling
	assert(rc <= LUA_YIELD);

	lua_pushboolean(L, 1);

	n = lua_gettop(task);
	lua_xmove(task, L, n);
	return n + 1;
}

int
luaopen_task (lua_State *L)
{
	lua_createtable (L, 0, 2);
	lua_pushcfunction (L, task_yield);
	lua_setfield (L, -2, "yield");
	lua_pushcfunction (L, task_resume);
	lua_setfield (L, -2, "resume");
	return 1;
}

