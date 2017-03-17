local ffi = require('ffi')
local os = require('os')

local levee = require("levee")
local meta = require("levee.meta")
local _ = require("levee._")

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
		#include <stdlib.h>
		#include <signal.h>
		#include <sysexits.h>
		#include <err.h>

		#include <${include}/lua.h>
		#include <${include}/lauxlib.h>
		#include <${include}/lualib.h>

		#include "${include}/levee.h"

		static Levee *state;

		static int
		pmain (lua_State *L)
		{
			int n = levee_require (state, "${name}.main");
			if (n > 0) {
				lua_pop (L, n);
			}
			return 0;
		}

		static void
		cleanup (void)
		{
			levee_destroy (state);
			state = NULL;
		}

		int
		main (int argc, const char *argv[])
		{
			signal (SIGPIPE, SIG_IGN);

			atexit (cleanup);

			state = levee_create ();
			levee_set_arg (state, argc, argv);

			int rc = 0;
			if (!levee_runf (state, pmain, 0, false)) {
				levee_report_error (state);
				rc = EX_DATAERR;
			}
			levee_destroy (state);
			state = NULL;
			return rc;
		}
]], {
	name = options.name,
	include = options.include or "levee",
	}))
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
    return ([[
Usage: %s build [-o <exe] [-n <name>] [--debug]
                   (<module> [module...] | -e <script>)

Options:
  -o <exe>, --out <exe>       # file to out to [default: ./a.out]
  -n <name>, --name <name>    # project name [default: name of first module
                              # listed]
  -e <script>                 # adhoc script to compile]]):format(meta.name)
	end,

	parse = function(argv)
		local options = {modules = {}}

		while argv:more() do
			local opt = argv:option()

			if opt == nil then
				local path = argv:next():gsub("/$", "")
				table.insert(options.modules, path)

			elseif opt == "debug" then
				options.debug = true

			elseif opt == "e" then
				options.script = argv:next()

			elseif opt == "o" or opt == "output" then
				options.exe = argv:next()

			elseif opt == "n" or opt == "name" then
				options.name = argv:next()

			elseif opt == "v" or opt == "version" then
				options.version = argv:next()
			end
		end

		if #options.modules == 0 then
			if not options.script then
				io.stderr:write("no modules or script provided\n")
				os.exit(1)
			end
			options.modules = nil

		else
			if options.script then
				io.stderr:write("either provide an adhoc script or a set of modules\n")
				os.exit(1)
			end

			local err, st = _.stat(options.modules[1])
			if err then err:exit() end

			if st:is_reg() then
				options.file = options.modules[1]
			end
		end


		if options.version then
			local v = _.version(options.version)
			if not v then
				io.stderr:write("invalid version string\n")
				os.exit(1)
			end

			if not meta.version:is_compatible(v) then
				io.stderr:write("required version is not compatible\n")
				os.exit(1)
			end
		end


		options.exe = options.exe or "./a.out"

		return options
	end,

	run = function(options)
		local tmp = os.tmpname()
		os.remove(tmp)
		assert(mkdir(tmp))

		local main = tmp .. "/main.c"
		local bundle = tmp .. "/bundle.c"

		output_bundle(bundle, options)
		output_main(main, options)

		local err, proc = _.path.procname()
		if err then err:exit() end

		local root = _.path.dirname(proc, 2)
		local lib = options.lib or root .. "/lib/liblevee.a"

		local build = {
			"cc",
			"-std=c99", "-Wall", "-Wextra", "-Werror", "-pedantic",

			--release
			"-O2", "-fomit-frame-pointer", "-march=native",

			"-I", root .. "/include",
			main, bundle,
			"-o", options.exe,
		}

		if options.debug then table.insert(build, "-g") end

		local platform = {
			linux = {
				"-D_BSD_SOURCE", "-D_GNU_SOURCE",
				"-pthread", "-Wl,--export-dynamic", "-static-libgcc",
				"-Wl,--whole-archive," .. lib .. ",--no-whole-archive",
				"-lm", "-ldl",
			},
			osx = {
				"-pagezero_size", "10000", "-image_base", "100000000",
				"-Wl,-export_dynamic",
				"-Wl,-force_load," .. lib,
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
