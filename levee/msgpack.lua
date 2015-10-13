local ffi = require("ffi")
local C = ffi.C

local errno = require("levee.errno")
local buffer = require("levee.buffer")


--
-- encode

local function encode_array(buf, n)
	local rc = C.sp_msgpack_enc_array(buf, n)
	assert(rc > 0)
	return rc
end


local function encode_map(buf, n)
	local rc = C.sp_msgpack_enc_map(buf, n)
	assert(rc > 0)
	return rc
end


local function encode_true(buf)
	local rc = C.sp_msgpack_enc_true(buf)
	assert(rc > 0)
	return rc
end


local function encode_false(buf)
	local rc = C.sp_msgpack_enc_false(buf)
	assert(rc > 0)
	return rc
end


local function encode_signed(buf, n)
	local rc = C.sp_msgpack_enc_signed(buf, n)
	assert(rc > 0)
	return rc
end


local function encode_unsigned(buf, n)
	local rc = C.sp_msgpack_enc_positive(buf, n)
	assert(rc > 0)
	return rc
end


local function encode_double(buf, n)
	local rc = C.sp_msgpack_enc_double(buf, n)
	assert(rc > 0)
	return rc
end


local function encode_string(buf, s)
	local rc = C.sp_msgpack_enc_string(buf, #s)
	assert(rc > 0)
	C.memmove(buf + rc, s, #s)
	return rc + #s
end


local function encode(data, buf)
	if not buf then
		buf = buffer(4096)
	else
		-- TODO: this will continue to grow the buffer as needed. it'd be nice to
		-- instead yield out 4k bufs so they can be put on the wire immediately
		buf:ensure(4096)
	end

	if type(data) == "table" then
		local n = 0
		for k, v in pairs(data) do n = n + 1 end
		if n == #data then
			-- this is an array
			local rc = encode_array(buf:tail(), n)
			buf:bump(rc)
			for _, v in ipairs(data) do
				buf = encode(v, buf)
			end
		else
			-- this is a map
			local rc = encode_map(buf:tail(), n)
			buf:bump(rc)
			for k, v in pairs(data) do
				buf = encode(k, buf)
				buf = encode(v, buf)
			end
		end

	elseif type(data) == "boolean" then
		if data then
			local rc = encode_true(buf:tail(), data)
			buf:bump(rc)
		else
			local rc = encode_false(buf:tail(), data)
			buf:bump(rc)
		end

	elseif type(data) == "string" then
		local rc = encode_string(buf:tail(), data)
		buf:bump(rc)

	elseif type(data) == "number" then
		if math.floor(data) == data then
			local rc = encode_signed(buf:tail(), data)
			buf:bump(rc)
		else
			local rc = encode_double(buf:tail(), data)
			buf:bump(rc)
		end

	else
		error("TODO: " .. type(data))
	end

	return buf
end


--
-- decode

local Msgpack_mt = {}
Msgpack_mt.__index = Msgpack_mt


function Msgpack_mt:init()
	C.sp_msgpack_init(self)
	return self
end


function Msgpack_mt:__new()
	return ffi.new(self):init()
end


function Msgpack_mt:is_done()
	return C.sp_msgpack_is_done(self)
end


function Msgpack_mt:next(eof, buf, len)
	return C.sp_msgpack_next(self, buf, len, eof)
end


function Msgpack_mt:stream_next(stream)
	local n = self:next(false, stream:value())

	if n < 0 then
		return false, ffi.string(C.sp_strerror(n))
	end

	if n > 0 then
		stream:trim(n)
		if self.type ~= C.SP_MSGPACK_NONE then
			return true
		end
	end

	local n, err = stream:readin()
	if n <= 0 then
		-- connection died
		return false, errno:message(err)
	end

	return self:stream_next(stream)
end


function Msgpack_mt:stream_value(stream)
	local ok, err = self:stream_next(stream)
	if not ok then return ok, err end
	print(ok, err)

	if self.type == C.SP_MSGPACK_MAP then
		local ob = {}
		local ok, key = self:stream_value(stream)
		print(ok, key)

	elseif self.type == C.SP_MSGPACK_STRING then
		print("string")

	else
		error("TODO: "..tostring(self.type))
	end
end


function Msgpack_mt:stream_consume(stream)
	-- stream methods:
	--	:readin()
	--	:value() -> returns char*, len (could return eof?)
	--	:trim(n)

	local ok, value = self:stream_value(stream)
	if not ok then return ok, value end
	assert(self:is_done())
	-- TODO: should we have a reset?
	-- self:reset()
	return true, value
end


local decoder = ffi.metatype("SpMsgpack", Msgpack_mt)


return {
	encode = encode,
	decoder = decoder,
}
