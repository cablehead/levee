local ffi = require('ffi')
local uname = ffi.os:lower()

local function check(ok, ...)
	if ok then return ok, ... end
	io.stderr:write("luajit: ", ...)
	io.stderr:write("\n")
	os.exit(1)
end


local cdef_tmp = 'require("ffi").cdef[[%s]]'

local function loadinfo(path, dir, name, debug)
	if (name == "linux" or name == "osx" or name == "bsd") and name ~= uname then
		return
	end

	local id = dir:gsub("/", ".")
	local cdef = false
	if name == "init" then
		cdef = id:sub(-4) == "cdef"
	else
		id = id .. "." .. name
	end

	f = check(loadfile(path))
	if cdef then
		local headers = table.concat(f(id), "\n")
		local lua = cdef_tmp:format(headers)
		f = loadstring(lua)
	end

	return {
		id = id,
		fname = id:gsub("%.", "_"),
		path = path,
		bytecode = string.dump(f, not debug)
	}
end


local function loadall(root, sub, debug)
	root = root:gsub("/$", "")
	sub = sub:gsub("^/", ""):gsub("/$", "")

	local dir = root .. "/" .. sub
	local match = "^" .. root .. "/(.+)/([^/]+).lua$"
	local t = {}
	for path in io.popen("find " .. dir .. " -name '*.lua'"):lines() do
		local dir, name = path:match(match)
		local f = loadinfo(path, dir, name, debug)
		if f then
			table.insert(t, f)
		end
	end
	return t
end


local function bytecode_array(file)
	local s = file.bytecode
	local bytes, lines = {}, {}
	local n, m = 0, 0
	for i=1,#s do
		local byte = tostring(string.byte(s, i))
		m = m + #byte + 1
		if m > 78 then
			table.insert(lines, table.concat(bytes, ",", 1, n))
			n, m = 0, #byte + 1
		end
		n = n + 1
		bytes[n] = byte
	end
	table.insert(lines, table.concat(bytes, ",", 1, n))
	return table.concat(lines, ",\n\t\t")
end


local loader_call_tmpl = [[
	static const char buf[] = {
		%s
	};
	if (luaL_loadbufferx (L, buf, sizeof buf, "%s", "b")) {
		lua_pop (L, 2);
		return 0;
	}
	lua_pushstring (L, "%s");
	lua_call (L, 1, 1);
]]

local function loader_call(file)
	return loader_call_tmpl:format(bytecode_array(file), file.id, file.id)
end


local loader_function_tmpl = [[
static int
load_%s (lua_State *L) {
%s
	return 1;
}
]]

local function loader_function(file)
	return loader_function_tmpl:format(file.fname, loader_call(file))
end


local preload_call_tmpl = [[
	lua_pushcfunction (L, load_%s);
	lua_setfield (L, -2, "%s");
]]

local function preload_call(file)
	return preload_call_tmpl:format(file.fname, file.id)
end


local preload_function_tmpl = [[
int
luaopen_%s (lua_State *L) {
	lua_getfield (L, LUA_REGISTRYINDEX, "_PRELOAD");

%s
	lua_pop (L, 1);
	return 0;
}
]]

local function preload_function(name, files)
	local calls = {}
	for i,file in ipairs(files) do
		table.insert(calls, preload_call(file))
	end
	return preload_function_tmpl:format(name, table.concat(calls, "\n"))
end


local function bundle(root, sub)
	-- TODO: make debug mode externally configurable
	local files = loadall(root, sub, true)
	for i,file in ipairs(files) do
		print(loader_function(file))
	end
	print(preload_function(sub, files))
end

print('#include <lua.h>')
print('#include <lauxlib.h>')
print('#include <lualib.h>')
for i=1,#arg,2 do
	if not arg[i+1] then break end
	bundle(arg[i], arg[i+1])
end

