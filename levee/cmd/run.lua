local os = require('os')

local levee = require("levee")
local meta = require("levee.meta")
local _ = require("levee._")


return {
	usage = function()
		return ("Usage: %s run (<path> | -e <script>) [arg...]"):format(meta.name)
	end,

	parse = function(argv)
		local options = {}

		if not argv:more() then return end

		local opt = argv:option()

		if opt then
			if opt ~= "e" then return end
			options.f, options.err = loadstring(argv:next())

		else
			local path = argv:next():gsub("/$", "")

			local err, st = _.stat(path)
			if err then
				err:exit()
			end

			if not (st:is_reg() or st:is_dir()) then
				io.stderr:write(("path is not a file or directory: %s\n"):format(path))
				os.exit(1)
			end

			if st:is_dir() then
				package.loaded[_.path.basename(path)..".assets"] = _.bundle.assets(
					_.path.join(path, "assets"))()
				package.loaded[_.path.basename(path)..".templates"] = _.bundle.templates(
					_.path.join(path, "templates"))()
				local root = _.path.dirname(path)
				if root == "" then root = "./" end
				package.path = (
					root .. "/?.lua;" ..
					root .. "/?/init.lua;" ..
					package.path)
				path = path .. "/main.lua"
			end

			options.f, options.err = loadfile(path)
		end

		if not options.f then
			io.stderr:write(options.err)
			io.stderr:write("\n")
			os.exit(1)
		end

		options.arg = argv:remain()
		return options
	end,

	run = function(options)
		arg = options.arg
		return options.f()
	end,
}
