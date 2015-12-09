local date = {
	year = 2015,
	month = 12,
	day = 3,
}

date.string = string.format(
	"%02d-%02d-%02d",
	date.year, date.month, date.day
)

return {
	name = "levee",
	version = {
		major = 0,
		minor = 3,
		patch = 2,
		pre_release = "-alpha",
		date = date, },
}
