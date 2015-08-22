local ffi = require("ffi")
local C = ffi.C


local Stat_mt = {}
Stat_mt.__index = Stat_mt

function Stat_mt:is_reg()
	return bit.band(self.st_mode, C.S_IFREG) ~= 0
end

function Stat_mt:is_dir()
	return bit.band(self.st_mode, C.S_IFDIR) ~= 0
end

ffi.metatype("struct levee_stat", Stat_mt)


local function nonblock(no)
	local flags = C.fcntl(no, C.F_GETFL, 0)
	if flags == -1 then
		return ffi.errno()
	end
	flags = bit.bor(flags, C.O_NONBLOCK)
	local rc = C.fcntl(no, C.F_SETFL, ffi.new("int", flags))
	if rc == -1 then
		return ffi.errno()
	end
	return 0
end


local function block(no)
	local flags = C.fcntl(no, C.F_GETFL, 0)
	if flags == -1 then
		return ffi.errno()
	end
	flags = bit.band(flags, bit.bnot(C.O_NONBLOCK))
	local rc = C.fcntl(no, C.F_SETFL, ffi.new("int", flags))
	if rc == -1 then
		return ffi.errno()
	end
	return 0
end


local nonblock_accept

if ffi.os:lower() == "linux" then
	nonblock_accept = nonblock
else
	nonblock_accept = function() end
end

local function read(no, buf, len)
	if not len then len = ffi.sizeof(buf) end
	local len = C.read(no, buf, len)
	if len > 0 then
		return len, 0
	else
		return len, ffi.errno()
	end
end


local function reads(no, len)
	len = len or 4096
	local buf = ffi.new("char[?]", len)
	local len = read(no, buf, len)
	if len >= 0 then
		return ffi.string(buf, len)
	end
end


local function write(no, buf, len)
	if not len then
		if type(buf) == "cdata" then
			len = ffi.sizeof(buf)
		else
			len = #buf
		end
	end
	local len = C.write(no, buf, len)
	if len > 0 then
		return len, 0
	else
		return len, ffi.errno()
	end
end

local function close(fd)
	return C.close(fd)
end

local function pipe()
	local fds = ffi.new("int[2]")
	assert(C.pipe(fds) == 0)
	return fds[0], fds[1]
end

local function fstat(no)
	local st = ffi.new("struct levee_stat")
	local rc = C.levee_fstat(no, st)
	if rc < 0 then return end
	return st
end

local function stat(path)
	local st = ffi.new("struct levee_stat")
	local rc = C.levee_stat(path, st)
	if rc < 0 then return end
	return st
end

function dirname(str)
	if str:match(".-/.-") then
		local name = string.gsub(str, "(.*/)(.*)", "%1")
		return name
	else
		return ''
	end
end

return {
	nonblock = nonblock,
	nonblock_accept = nonblock_accept,
	block = block,
	read = read,
	reads = reads,
	write = write,
	close = close,
	pipe = pipe,
	fstat = fstat,
	stat = stat,
	dirname = dirname,
}
