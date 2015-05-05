local ffi = require("ffi")

function dirname(str)
	if str:match(".-/.-") then
		local name = string.gsub(str, "(.*)(/.*)", "%1")
		return name
	else
		return ''
	end
end

function __FILE__() return debug.getinfo(2,'S').source:sub(2) end

local path = dirname(__FILE__())
local os = ffi.os:lower()
local arch = ffi.arch

function try_include(full)
	local fh = io.open(full, "r")
	if not fh then return false end
	local header = fh:read("*all")
	fh:close()
	local ok, msg = pcall(ffi.cdef,header)
	if ok then
		return true
	else
		error(string.format("%s: %s", full, msg), 2)
	end
end

function include(name, ...)
	local full = path.."/"..name.."/"..table.concat({...}, "-")..".h"
	if not try_include(full) then
		error("failed to load header: " .. full, 2)
	end
end

include("std", arch)
include("std", "std")
include("time", "time")
include("math", "math")
include("socket", "socket")
include("socket", os)
include("fcntl", os)
include("ioctl", os)
include("poller", os)
