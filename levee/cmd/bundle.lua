local io = require('io')
local os = require('os')


local function dirname(str)
	if str:match(".-/.-") then
		local name = string.gsub(str, "(.*/)(.*)", "%1")
		return name
	else
		return ''
	end
end


local function basename(s)
	local name = string.gsub(s, "(.*/)(.*)", "%2")
	return name
end


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
	local id = file:sub(#root + 1, -5):gsub("/", "."):gsub(".init$", "")
	local f = check(loadfile(file))
	return {
		id = id,
		req_name = id,
		func_name = id:gsub("%.", "_"),
		path = path,
		bytecode = string.dump(f, not debug)
	}
end


local function collect(path, files, debug)
	for file in io.popen("find -L '" .. path .. "' -name '*.lua'"):lines() do
		local f = collect_file(dirname(path), file, debug)
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
	]]):format(file.func_name, file.req_name)
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


local function output_bundle(out, inc, name, files)
	out:write('#include <'..inc..'/lua.h>\n')
	out:write('#include <'..inc..'/lauxlib.h>\n')
	out:write('#include <'..inc..'/lualib.h>\n')

	for i, file in ipairs(files) do
		out:write(output_file(file))
		out:write("\n")
	end

	out:write(output_open(name, files))
	out:write("\n")
end


return {
	usage = function()
    return ([[Usage: %s bundle [-o <file] [-n <name>] <module> [module...]

Options:
  -o <file>, --out <file>     # file to out to [default: stdout]
  -n <name>, --name <name>    # bundle name [default: name of first module
                              # listed]
  -f <file>, --file <file>    # bundle a single file
  ]]):format(require("levee.meta").name)
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

			elseif opt == "f" or opt == "file" then
				options.file = argv:next()

			end
		end

		if #options.modules == 0 and not options.file then
			io.stderr:write("no modules provided\n")
			os.exit(1)
		end

		options.out = options.out or io.stdout

		return options
	end,

	run = function(options)
		local files = {}
		local inc = options.include or "levee"
		local debug = true

		if options.script then
			options.name = options.name or "__script"
			local f = check(loadstring(options.script))
			table.insert(files, {
				id = "__script",
				req_name = "__script.main",
				func_name = "__script",
				bytecode = string.dump(f), })

		elseif options.file then
			options.name = options.name or basename(options.file:match("^(.+)%..+$"))
			local f = collect_file(dirname(options.file), options.file, debug)
			if f then
				f.req_name = f.req_name .. ".main"
				table.insert(files, f)
			end
		else
			options.name = options.name or basename(options.modules[1])
			for _, path in ipairs(options.modules) do
				-- TODO: make debug mode externally configurable
				collect(path, files, debug)
			end
		end

		output_bundle(options.out, inc, options.name, files)
	end,
}
