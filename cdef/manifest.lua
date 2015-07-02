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
	local ok, msg = pcall(ffi.cdef, header)
	if ok then
		return header
	else
		error(string.format("%s: %s", full, msg), 2)
	end
end

function include(name, ...)
	local full = path.."/"..name.."/"..table.concat({...}, "-")..".h"
	return try_include(full)
end

local headers = {
	include("std", arch),
	include("std", "std"),
	include("types", os),
	include("time", "time"),
	include("time", os),
	include("stat", "stat"),
	include("sendfile", "sendfile"),
	include("math", "math"),
	include("socket", "socket"),
	include("socket", os),
	include("fcntl", os),
	include("ioctl", os),
	include("poller", os),
	include("heap", "heap"),
	include("list", "list"),
	include("channel", "channel"),
	include("siphon", "common"),
	include("siphon", "error"),
	include("siphon", "utf8"),
	include("siphon", "http"),
	include("siphon", "uri"),
	include("siphon", "hash"),
	include("siphon", "rand"),
	include("siphon", "bloom"),
	include("siphon", "json"),
	include("levee", "levee"),
}

print(table.concat(headers, "\n"))
