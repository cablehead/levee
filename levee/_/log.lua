-- super ghetto, quick log stub to iterate quickly on potential log layouts
-- this version is more human friendly for local console
-- should be implemented in Siphon


local time = require("levee._.time")


local LEVELS = {
	DEBUG = 10,
	INFO = 20,
	WARN = 30,
	ERROR = 40,
}


local Log_mt = {}
Log_mt.__index = Log_mt


function Log_mt:log(lvl, f, ...)
	if LEVELS[lvl] >= self.lvl then
		io.write(("%-5s"):format(lvl))
		io.write(" ")
		io.write(time.now():localdate():iso8601())
		io.write(" ")
		io.write(("%-21s"):format(self.name:sub(1,20)))
		io.write(f:format(...))
		io.write("\n")
		io.flush()
	end
end


function Log_mt:debug(...)
	return self:log("DEBUG", ...)
end


function Log_mt:info(...)
	return self:log("INFO", ...)
end


function Log_mt:warn(...)
	return self:log("WARN", ...)
end


function Log_mt:error(...)
	return self:log("ERROR", ...)
end


return {
	Log = function(name)
		return setmetatable({name=name, lvl=LEVELS["INFO"]}, Log_mt)
	end,

	patch = function(f)
		local ret = Log_mt.log
		Log_mt.log = f
		return ret
	end,
}
