require("levee.cdef")

local ffi = require('ffi')

ffi.cdef[[
struct LeveeDate {
	struct tm base;
	time_t tv_usec;
};
]]

local C = ffi.C



local months = {
	"January", "February", "March", "April", "May", "June", "July", "August",
	"September", "October", "November", "December"
}

local abbr_months = {
	"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
}

local days = {
	"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
}

local abbr_days = {
	"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
}



local Date = {}
Date.__index = Date

function Date:copy()
	local new = Date.allocate(self)
	C.memcpy(new, self, ffi.sizeof(self))
	return new
end

function Date:microsecond() return self.tv_usec end
function Date:second() return self.base.tm_sec end
function Date:minute() return self.base.tm_min end
function Date:hour() return self.base.tm_hour end
function Date:day() return self.base.tm_mday end
function Date:month() return self.base.tm_mon + 1 end
function Date:year() return self.base.tm_year + 1900 end
function Date:weekday() return self.base.tm_wday + 1 end

function Date:isdst()
	return self.base.tm_isdst ~= 0
end

function Date:isleap()
	local y = self:year()
	return not (y%4) and ((y%100) or not (y%400))
end

function Date:timezone_offset()
	return self.base.tm_gmtoff
end

function Date:timezone_string()
	return string.format("%+.2d:%.2d",
		tonumber((self.base.tm_gmtoff)/3600),
		math.abs(tonumber(self.base.tm_gmtoff%3600)/60))
end

function Date:timezone_name()
	return ffi.string(self.base.tm_zone)
end

function Date:__tostring()
	local tz
	if self.base.tm_gmtoff == 0 then
		tz = "Z"
	else
		tz = self:timezone_string()
	end
	return string.format("%04d-%02d-%02dT%02d:%02d:%02d.%06d%s",
		self:year(), self:month(), self:day(),
		self:hour(), self:minute(), self:second(), tonumber(self.tv_usec), tz)
end

Date.allocate = ffi.metatype("struct LeveeDate", Date)



local Time = {}
Time.__index = Time

local function time_seconds(n)
	local sec = ffi.new('double[1]')
	local frac = C.modf(n, sec)
	return Time.allocate(sec[0], frac * 1000000)
end

local function time_now()
	return Time.allocate():update()
end

function Time:copy()
	return Time.allocate(self.tv_sec, self.tv_usec)
end

function Time:seconds()
	return tonumber(self.tv_sec) + tonumber(self.tv_usec)/1000000.0
end

function Time:add(time)
	if type(time) == "number" then
		time = time_seconds(time)
	end
	self.tv_sec = self.tv_sec + time.tv_sec
	self.tv_usec = self.tv_usec + time.tv_usec
	if self.tv_usec >= 1000000ULL then
		self.tv_sec = self.tv_sec + 1ULL
		self.tv_usec = self.tv_usec - 1000000ULL
	end
	return self
end

function Time:utcdate()
	local d = Date.allocate()
	C.gmtime_r(ffi.cast('time_t *', self), d.base)
	d.tv_usec = self.tv_usec
	return d
end

function Time:locdate()
	local d = Date.allocate()
	C.localtime_r(ffi.cast('time_t *', self), d.base)
	d.tv_usec = self.tv_usec
	return d
end

function Time:update()
	C.gettimeofday(self, nil)
	return self
end

function Time:next()
	local seconds = self:seconds()
	return self:update():seconds() - seconds
end

function Time:__tostring()
	return string.format("levee.Time: %d.%d", tonumber(self.tv_sec), tonumber(self.tv_usec))
end

function Time:__add(time)
	local add = Time.allocate(self.tv_sec + time.tv_sec, self.tv_usec + time.tv_usec)
	if add.tv_usec >= 1000000ULL then
		add.tv_sec = add.tv_sec + 1ULL
		add.tv_usec = add.tv_usec - 1000000ULL
	end
	return add
end

function Time:__eq(time)
	return self.tv_sec == time.tv_sec and self.tv_usec == time.tv_usec
end

function Time:__lt(time)
	return self.tv_sec < time.tv_sec or (self.tv_sec == time.tv_sec and self.tv_usec < time.tv_usec)
end

function Time:__le(time)
	return self.tv_sec < time.tv_sec or (self.tv_sec == time.tv_sec and self.tv_usec <= time.tv_usec)
end

Time.allocate = ffi.metatype("struct timeval", Time)

return {
	Time = time_seconds,
	now = time_now,
	utcdate = function() return time_now():utcdate() end,
	locdate = function() return time_now():locdate() end
}
