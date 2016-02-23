-- super ghetto, quick log stub to iterate quickly on potential log layouts
-- this version is more human friendly for local console
-- should be implemented in Siphon


local time = require("levee._.time")


local Log_mt = {}
Log_mt.__index = Log_mt


function Log_mt:log(lvl, f, ...)
	io.write(lvl)
	io.write(" ")
	io.write(time.now():localdate():iso8601())
	io.write(" ")
	io.write(("%-21s"):format(self.name:sub(1,20)))
	io.write(f:format(...))
	io.write("\n")
	io.flush()
end


function Log_mt:debug(...)
	return self:log("DEBUG", ...)
end


function Log_mt:info(...)
	return self:log("INFO ", ...)
end


function Log_mt:warn(...)
	return self:log("WARN ", ...)
end


return {
	Log = function(name)
		return setmetatable({name=name}, Log_mt)
	end,

	patch = function(f)
		local ret = Log_mt.log
		Log_mt.log = f
		return ret
	end,
}
