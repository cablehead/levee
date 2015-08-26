local os = require('os')

local levee = require("levee")


return {
	usage = function()
		return "Usage: levee run <path> [arg...]"
	end,

	parse = function(argv)
		local options = {}

		if not argv:more() then return end
		local path = argv:next():gsub("/$", "")

		local st = levee.sys.os.stat(path)
		if not st or not (st:is_reg() or st:is_dir()) then
			io.stderr:write(("invalid path: %s\n"):format(path))
			os.exit(1)
		end

		if st:is_dir() then
			package.path = (levee.sys.os.dirname(path) .. "/?.lua;" ..
				levee.sys.os.dirname(path) .. "/?/init.lua;" .. package.path)
			options.main = path .. "/main.lua"
		else
			options.main = path
		end

		options.arg = argv:remain()

		return options
	end,

	run = function(options)
		arg = options.arg
		local f, err = loadfile(options.main)
		if f then
			f()
		else
			io.stderr:write(err)
			io.stderr:write("\n")
		end
	end,
}

