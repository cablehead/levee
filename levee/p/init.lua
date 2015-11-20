local ffi = require("ffi")

local StringStream_mt = {}
StringStream_mt.__index = StringStream_mt

function StringStream_mt:readin()
end

function StringStream_mt:value()
	return self.buf, self.n
end

function StringStream_mt:trim(n)
	assert(self.n >= n)
	self.buf = self.buf + n
	self.n = self.n - n
end

function StringStream_mt:peek(n)
	if n then
		n = n < self.n and n or self.n
	else
		n = self.n
	end
	if n == 0ULL then return "" end
	return ffi.string(self.buf, n)
end

function StringStream_mt:take(n)
	local value = self:peek(n)
	self:trim(#value)
	return value
end

local ctype_buffer = ffi.typeof("struct LeveeBuffer")

local function StringStream(s, len)
	local buf, n
	if ffi.istype(ctype_buffer, s) then
		buf, n = s:value()
	else
		buf = ffi.cast("uint8_t *", s)
		n = len or #s
	end
	return setmetatable({buf=buf, n=n}, StringStream_mt)
end

local json = require("levee.p.json")
local msgpack = require("levee.p.msgpack")

json.StringStream = StringStream
msgpack.StringStream = StringStream

return {
	json = json,
	msgpack = msgpack,
	http = require("levee.p.http"),
	uri = require("levee.p.uri"),
}
