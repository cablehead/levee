local ffi = require("ffi")

function dirname(str)
	if str:match(".-/.-") then
		local name = string.gsub(str, "(.*/)(.*)", "%1")
		return name
	else
		return ''
	end
end

function __FILE__() return debug.getinfo(2,'S').source:sub(2) end

local path = dirname(__FILE__())

local fh = io.open(path..ffi.os:lower()..".h", "r")
local header = fh:read("*all")
fh:close()

ffi.cdef(header)
