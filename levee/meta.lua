local date = {
	year = 2015,
	month = 10,
	day = 19
}

date.string = string.format(
	"%d-%d-%d",
	date.year, date.month, date.day
)

return {
	major = 0,
	minor = 2,
	patch = 0,
	date = date
}
