local ffi = require("ffi")
local os = require("os")
local io = require("io")

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
	if not fh then return "" end
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
	include("process", "process"),
	include("process", os),
	include("time", "time"),
	include("time", os),
	include("signal", "signal"),
	include("signal", os),
	include("stat", "stat"),
	include("sendfile", "sendfile"),
	include("math", "math"),
	include("socket", "socket"),
	include("socket", os),
	include("fcntl", os),
	include("ioctl", "ioctl"),
	include("ioctl", os),
	include("poller", os),
	include("buffer", "buffer"),
	include("heap", "heap"),
	include("list", "list"),
	include("channel", "channel"),
	include("siphon", "common"),
	include("siphon", "hash"),
	include("siphon", "error"),
	include("siphon", "utf8"),
	include("siphon", "http"),
	include("siphon", "uri"),
	include("siphon", "rand"),
	include("siphon", "bloom"),
	include("siphon", "json"),
	include("siphon", "msgpack"),
	include("siphon", "path"),
	include("siphon", "map"),
	include("siphon", "ring"),
	include("levee", "levee"),
}

local out
if arg[1] == "-" or arg[1] == nil then
	out = io.stdout
else
	out = io.open(arg[1], "w")
end


local function bytearray(s, indent)
	local bytes, lines = {}, {}
	local n, m = 0, 0
	for i=1,#s do
		local byte = tostring(string.byte(s, i))
		m = m + #byte + 1
		if m > 78 then
			table.insert(lines, table.concat(bytes, ",", 1, n))
			n, m = 0, #byte + 1
		end
		n = n + 1
		bytes[n] = byte
	end
	table.insert(lines, table.concat(bytes, ",", 1, n))
	return table.concat(lines, ",\n" .. indent)
end


out:write("const char levee_cdef[] = {\n\t")
out:write(bytearray(table.concat(headers, "\n"), "\t"))
out:write(",0\n};\n")
