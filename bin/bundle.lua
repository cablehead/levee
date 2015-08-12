local ffi = require('ffi')
local io = require('io')
local uname = ffi.os:lower()

local out
if arg[1] == "-" then
	out = io.stdout
else
	out = io.open(arg[1], "w")
	if out == nil then
		error("failed to open '"..arg[1].."' for writing")
	end
end

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

	-- TODO: we should escape all special characters eventually
	local root_escaped = root:gsub("-", "%%-")
	
	local dir = root .. "/" .. sub
	local match = "^" .. root_escaped .. "/(.+)/([^/]+).lua$"
	local t = {}
	for path in io.popen("find -L " .. dir .. " -name '*.lua'"):lines() do
		local dir, name = path:match(match)
		local f = loadinfo(path, dir, name, debug)
		if f then
			table.insert(t, f)
		end
	end
	return t
end


local function bytearray(s, indent)
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
	return table.concat(lines, ",\n" .. indent)
end


local function bytecode_array(file)
	return bytearray(file.bytecode, "\t\t")
end


local loader_call_tmpl = [[
	static const unsigned char buf[] = {
		%s
	};
	if (luaL_loadbufferx (L, (const char *)buf, sizeof buf, "%s", "b")) {
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
luaopen_%s_bundle (lua_State *L) {
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


local function bundle(root, sub, all)
	-- TODO: make debug mode externally configurable
	local files = loadall(root, sub, true)
	for i, file in ipairs(files) do
		out:write(loader_function(file))
		out:write("\n")
		table.insert(all, file)
	end
end

out:write('#include <lua.h>\n')
out:write('#include <lauxlib.h>\n')
out:write('#include <lualib.h>\n')

local files = {}

for i=3,#arg,2 do
	if not arg[i+1] then break end
	bundle(arg[i], arg[i+1], files)
end

out:write(preload_function(arg[2], files))
out:write("\n")
