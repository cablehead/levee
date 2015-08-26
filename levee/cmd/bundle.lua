local io = require('io')
local os = require('os')

local levee = require("levee")


local function check(ok, ...)
	if ok then return ok, ... end
	io.stderr:write("luajit: ", ...)
	io.stderr:write("\n")
	os.exit(1)
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


local function bytecode(file)
	return bytearray(file.bytecode, "\t\t")
end


--
-- collect

local function collect_file(root, file, debug)
	local id = file:sub(#root + 1, -5):gsub("/", ".")
	local f = check(loadfile(file))
	return {
		id = id,
		func_name = id:gsub("%.", "_"),
		path = path,
		bytecode = string.dump(f, not debug)
	}
end


local function collect(path, files, debug)
	for file in io.popen("find -L '" .. path .. "' -name '*.lua'"):lines() do
		local f = collect_file(levee.sys.os.dirname(path), file, debug)
		if f then table.insert(files, f) end
	end
end


--
-- output

local function output_bytecode(file)
	return ([[
		static const unsigned char buf[] = {
			%s
		};
		if (luaL_loadbufferx (L, (const char *)buf, sizeof buf, "%s", "b")) {
			lua_pop (L, 2);
			return 0;
		}
		lua_pushstring (L, "%s");
		lua_call (L, 1, 1);
	]]):format(bytecode(file), file.id, file.id)
end


local function output_file(file)
	return ([[
	static int
	load_%s (lua_State *L) {
	%s
		return 1;
	}
	]]):format(file.func_name, output_bytecode(file))
end


local function output_open_file(file)
	return ([[
		lua_pushcfunction (L, load_%s);
		lua_setfield (L, -2, "%s");
	]]):format(file.func_name, file.id)
end


local function output_open(name, files)
	local calls = {}
	for i, file in ipairs(files) do
		table.insert(calls, output_open_file(file))
	end
	return ([[
		int
		luaopen_%s (lua_State *L) {
			lua_getfield (L, LUA_REGISTRYINDEX, "_PRELOAD");

		%s
			lua_pop (L, 1);
			return 0;
		}
		]]):format(name, table.concat(calls, "\n"))
end


local function output_bundle(out, name, files)
	out:write('#include <levee/lua.h>\n')
	out:write('#include <levee/lauxlib.h>\n')
	out:write('#include <levee/lualib.h>\n')

	for i, file in ipairs(files) do
		out:write(output_file(file))
		out:write("\n")
	end

	out:write(output_open(name, files))
	out:write("\n")
end


return {
	usage = function()
    return [[usage: levee bundle [-o <file] [-n <name>] <module> [module...]

options:
  -o <file>, --out <file>     # file to out to [default: stdout]
  -n <name>, --name <name>    # bundle name [default: name of first module
                              # listed]
  ]]
	end,

	parse = function(argv)
		local options = {modules = {}}

		while argv:more() do
			local opt = argv:option()

			if opt == nil then
				local path = argv:next():gsub("/$", "")
				table.insert(options.modules, path)

			elseif opt == "o" or opt == "output" then
				options.out = argv:output()

			elseif opt == "n" or opt == "name" then
				options.name = argv:next()
			end
		end

		if #options.modules == 0 then
			io.stderr:write("no modules provided\n")
			os.exit(1)
		end

		options.name = options.name or levee.sys.os.basename(options.modules[1])
		options.out = options.out or io.stdout

		return options
	end,

	run = function(options)
		local files = {}

		for _, path in ipairs(options.modules) do
			-- TODO: make debug mode externally configurable
			collect(path, files, true)
		end

		output_bundle(options.out, options.name, files)
	end,
}
