local Version = require("levee._.version")

local date = {
	year = 2016,
	month = 5,
	day = 21,
}

date.string = string.format(
	"%02d-%02d-%02d",
	date.year, date.month, date.day
)

local version = Version{
	major = 0,
	minor = 3,
	patch = 3,
}

version.date = date
version.string = tostring(version)

return {
	name = "levee",
	version = version,
}
