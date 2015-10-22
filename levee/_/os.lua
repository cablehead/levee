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



local function close(fd)
	return C.close(fd)
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

function dirname(s)
	if s:match(".-/.-") then
		return string.gsub(s, "(.*/)(.*)", "%1"):gsub("/$", "")
	end
	return ''
end

function basename(s)
	local name = string.gsub(s, "(.*/)(.*)", "%2")
	return name
end

local M = {
	nonblock = nonblock,
	nonblock_accept = nonblock_accept,
	block = block,
	read = read,
	reads = reads,
	close = close,

	pipe = function()
		local fds = ffi.new("int[2]")
		if C.pipe(fds) == 0 then
			return nil, fds[0], fds[1]
		end
		return errors.get(ffi.errno())
	end,

	write = function(no, buf, len)
		if not len then
			if type(buf) == "cdata" then
				len = ffi.sizeof(buf)
			else
				len = #buf
			end
		end
		local n = C.write(no, buf, len)
		if n > 0 then return nil, tonumber(n) end
		return errors.get(ffi.errno())
	end,

	read = function(no, buf, len)
		if not len then len = ffi.sizeof(buf) end
		local n = C.read(no, buf, len)
		if n > 0 then return nil, tonumber(n) end
		return errors.get(ffi.errno())
	end,

	fstat = fstat,
	stat = stat,
	dirname = dirname,
	basename = basename,
}

M.reads = function(no, len)
	len = len or 4096
	local buf = ffi.new("char[?]", len)
	local err, n = M.read(no, buf, len)
	if err then return err end
	return nil, ffi.string(buf, n)
end

return M
