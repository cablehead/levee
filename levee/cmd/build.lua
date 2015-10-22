local ffi = require('ffi')
local os = require('os')

local dirname = require("levee._.os").dirname
local basename = require("levee._.os").basename

local bundle = require("levee.cmd.bundle")


local function mkdir(name)
	return os.execute("mkdir " .. name)
end


local function template(s, t)
	return (s:gsub('($%b{})', function(w) return t[w:sub(3, -2)] or w end))
end


local function output_main(path, options)
	local fh = io.open(path, "w")
	fh:write(template([[
		#include <signal.h>
		#include <sysexits.h>
		#include <err.h>

		#include <levee/lua.h>
		#include <levee/lauxlib.h>
		#include <levee/lualib.h>

		#include "levee/levee.h"

		extern int
		luaopen_${name} (lua_State *L);

		const LeveeConfig config = {
			.init = luaopen_${name}
		};

		int
		main (int argc, const char *argv[])
		{
			signal (SIGPIPE, SIG_IGN);

			levee_init (&config);
			Levee *state = levee_create ();
			levee_set_arg (state, argc-1, argv+1);

			lua_getglobal (state->L, "require");
			lua_pushstring (state->L, "${name}.main");
			lua_call (state->L, 1, 1);

			int rc = 0;
			if (!levee_run (state, 0, false)) {
				levee_report_error (state);
				rc = EX_DATAERR;
			}

			levee_destroy (state);
			return rc;
		}
]], {name = options.name}))
	fh:close()
end


local function output_bundle(path, options)
	local fh = io.open(path, "w")
	options.out = fh
	bundle.run(options)
	fh:close()
end


return {
	usage = function()
    return [[Usage: levee build [-o <exe] [-n <name>] <module> [module...]

Options:
  -o <exe>, --out <exe>     # file to out to [default: ./a.out]
  -n <name>, --name <name>    # project name [default: name of first module
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
				options.exe = argv:next()

			elseif opt == "n" or opt == "name" then
				options.name = argv:next()
			end
		end

		if #options.modules == 0 then
			io.stderr:write("no modules provided\n")
			os.exit(1)
		end

		options.name = options.name or basename(options.modules[1])
		options.exe = options.exe or "./a.out"

		return options
	end,

	run = function(options)
		local tmp = os.tmpname()
		os.remove(tmp)
		assert(mkdir(tmp))

		local main = tmp .. "/main.c"
		local bundle = tmp .. "/bundle.c"

		output_main(main, options)
		output_bundle(bundle, options)

		local proc = levee.path.proc()
		local root = dirname(dirname(proc))

		local build = {
			"cc",
			"-std=c99", "-Wall", "-Wextra", "-Werror", "-pedantic",

			-- TODO: make switchable with release
			-- debug
			-- "-g",

			--release
			"-O2", "-fomit-frame-pointer", "-march=native",

			"-I", root .. "/include",
			main, bundle,
			"-o", options.exe,
		}

		local platform = {
			linux = {
				"-D_BSD_SOURCE", "-D_GNU_SOURCE",
				"-pthread", "-Wl,--export-dynamic", "-static-libgcc",
				"-lm", "-ldl",
				"-Wl,--whole-archive," .. root .. "/lib/liblevee.a,--no-whole-archive",
			},
			osx = {
				"-pagezero_size", "10000", "-image_base", "100000000",
				"-Wl,-export_dynamic",
				"-Wl,-force_load," .. root .. "/lib/liblevee.a",
			},
		}

		for _, extra in ipairs(platform[ffi.os:lower()]) do
			table.insert(build, extra)
		end

		build = table.concat(build, " ")
		local ok = os.execute(build)

		if ok then
			os.execute("rm -rf " .. tmp)
			return
		end

		print()
		print("build failed. you can inspect things here: " .. tmp)
	end,
}
