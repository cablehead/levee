require("levee.cdef")

local ffi = require('ffi')

ffi.cdef[[
struct LeveeDate {
	struct tm base;
	struct timeval tv;
};
]]

local C = ffi.C



local months = {
	"January", "February", "March", "April", "May", "June", "July", "August",
	"September", "October", "November", "December"
}

local months_abbr = {
	"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
}

local weekdays = {
	"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
}

local weekdays_abbr = {
	"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
}



local Date = {}
Date.__index = Date

function Date:copy()
	local new = Date.allocate(self)
	C.memcpy(new, self, ffi.sizeof(self))
	return new
end

function Date:microsecond() return self.tv.tv_usec end
function Date:second() return self.base.tm_sec end
function Date:minute() return self.base.tm_min end
function Date:hour() return self.base.tm_hour end
function Date:day() return self.base.tm_mday end
function Date:month() return self.base.tm_mon + 1 end
function Date:month_name() return months[self:month()] end
function Date:month_abbr() return months_abbr[self:month()] end
function Date:year() return self.base.tm_year + 1900 end
function Date:weekday() return self.base.tm_wday + 1 end
function Date:weekday_name() return weekdays[self:weekday()] end
function Date:weekday_abbr() return weekdays_abbr[self:weekday()] end

function Date:tz_offset()
	return self.base.tm_gmtoff
end

function Date:tz_string()
	return string.format("%+.2d:%.2d",
		tonumber((self.base.tm_gmtoff)/3600),
		math.abs(tonumber(self.base.tm_gmtoff%3600)/60))
end

function Date:tz_name()
	return ffi.string(self.base.tm_zone)
end

function Date:isdst()
	return self.base.tm_isdst ~= 0
end

function Date:isleap()
	local y = self:year()
	return not (y%4) and ((y%100) or not (y%400))
end

function Date:isutc()
	return self.base.tm_gmtoff == 0
end

function Date:utcdate()
	if self:isutc() then
		return self
	else
		return self.tv:utcdate()
	end
end

function Date:localdate()
	if self:isutc() then
		return self.tv:localdate()
	else
		return self
	end
end

function Date:time()
	return self.tv:copy()
end

function Date:__tostring()
	local tz
	if self:isutc() then
		tz = "Z"
	else
		tz = self:tz_string()
	end
	return string.format("%04d-%02d-%02dT%02d:%02d:%02d.%06d%s",
		self:year(), self:month(), self:day(),
		self:hour(), self:minute(), self:second(), tonumber(self.tv.tv_usec), tz)
end

function Date:__eq(date)
	return self.tv == date.tv
end

function Date:__lt(date)
	return self.tv < date.tv
end

function Date:__le(date)
	return self.tv <= date.tv
end

Date.allocate = ffi.metatype("struct LeveeDate", Date)



local Time = {}
Time.__index = Time

local function time_seconds(sec, usec)
	if not usec then
		local int = ffi.new('double[1]')
		local frac = C.modf(sec, int)
		sec = int[0]
		usec = frac * 1000000
	end
	return Time.allocate(sec, usec)
end

local function time_now()
	local self = Time.allocate()
	C.gettimeofday(self, nil)
	return self
end

local function totime(time)
	if ffi.istype(Time.allocate, time) then
		return time
	end
	return time_seconds(time)
end

function Time:copy()
	return Time.allocate(self.tv_sec, self.tv_usec)
end

function Time:seconds()
	return tonumber(self.tv_sec) + tonumber(self.tv_usec)/1000000.0
end

function Time:add(time)
	time = totime(time)
	self.tv_sec = self.tv_sec + time.tv_sec
	self.tv_usec = self.tv_usec + time.tv_usec
	if self.tv_usec >= 1000000LL then
		self.tv_sec = self.tv_sec + 1LL
		self.tv_usec = self.tv_usec - 1000000LL
	end
	return self
end

function Time:sub(time)
	time = totime(time)
	self.tv_sec = self.tv_sec - time.tv_sec
	self.tv_usec = self.tv_usec - time.tv_usec
	if self.tv_usec < 0LL then
		self.tv_sec = self.tv_sec - 1LL
		self.tv_usec = self.tv_usec + 1000000LL
	end
	return self
end

function Time:utcdate()
	local d = Date.allocate()
	C.gmtime_r(ffi.cast('time_t *', self), d.base)
	C.memcpy(d.tv, self, ffi.sizeof(self))
	return d
end

function Time:localdate()
	local d = Date.allocate()
	C.localtime_r(ffi.cast('time_t *', self), d.base)
	C.memcpy(d.tv, self, ffi.sizeof(self))
	return d
end

function Time:__tostring()
	return string.format("levee.Time: %d.%d", tonumber(self.tv_sec), tonumber(self.tv_usec))
end

function Time:__add(time)
	return self:copy():add(time)
end

function Time:__sub(time)
	return self:copy():sub(time)
end

function Time:__eq(time)
	time = totime(time)
	return self.tv_sec == time.tv_sec and self.tv_usec == time.tv_usec
end

function Time:__lt(time)
	time = totime(time)
	return self.tv_sec < time.tv_sec or (self.tv_sec == time.tv_sec and self.tv_usec < time.tv_usec)
end

function Time:__le(time)
	time = totime(time)
	return self.tv_sec < time.tv_sec or (self.tv_sec == time.tv_sec and self.tv_usec <= time.tv_usec)
end

Time.allocate = ffi.metatype("struct timeval", Time)



local Timer = {}
Timer.__index = Timer

if ffi.os == "OSX" then
	ffi.cdef[[
	struct LeveeTimer {
		uint64_t time;
	};
	]]

	local info = ffi.new("struct mach_timebase_info")
	assert(C.mach_timebase_info(info) == 0)

	if info.numer == info.denom then
		info = nil
		function Timer:next()
			local now = C.mach_absolute_time()
			local nsec = now - self.time
			self.time = now
			return nsec
		end
	else
		function Timer:next()
			local now = C.mach_absolute_time()
			local nsec = (now - self.time) * info.numer / info.denom
			self.time = now
			return nsec
		end
	end

	function Timer:reset()
		self.time = C.mach_absolute_time()
		return self
	end
else
	ffi.cdef[[
	struct LeveeTimer {
		struct timespec ts;
	};
	]]

	function Timer:next()
		local old = self.ts.tv_sec * 100000000ULL + self.ts.tv_nsec
		self:reset()
		return (self.ts.tv_sec * 100000000ULL + self.ts.tv_nsec) - old
	end

	function Timer:reset()
		C.clock_gettime(C.CLOCK_MONOTONIC_RAW, self.ts)
		return self
	end
end

Timer.allocate = ffi.metatype("struct LeveeTimer", Timer)



return {
	Time = time_seconds,
	now = time_now,
	utcdate = function() return time_now():utcdate() end,
	localdate = function() return time_now():localdate() end,
	Timer = function()
		return Timer.allocate():reset()
	end,
}
