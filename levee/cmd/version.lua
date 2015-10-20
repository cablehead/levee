local version = require("levee.version")

return {
	usage = function()
		return "Usage: levee version"
	end,

	parse = function(argv)
		return {}
	end,

	run = function(options)
		print(string.format("Levee version %d.%d %s",
				version.major, version.minor, version.date.string))
		print(string.format("Copyright (c) %d Imgix",
				version.date.year))
	end
}

