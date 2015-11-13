local ffi = require("ffi")
local C = ffi.C

local errors = require("levee.errors")
local d = require("levee.d")


--
-- encode

local function encode_array(buf, n)
	local rc = C.sp_msgpack_enc_array(buf, n)
	if rc >= 0 then return nil, rc end
	return errors.get(rc)
end


local function encode_map(buf, n)
	local rc = C.sp_msgpack_enc_map(buf, n)
	if rc >= 0 then return nil, rc end
	return errors.get(rc)
end


local function encode_true(buf)
	local rc = C.sp_msgpack_enc_true(buf)
	if rc >= 0 then return nil, rc end
	return errors.get(rc)
end


local function encode_false(buf)
	local rc = C.sp_msgpack_enc_false(buf)
	if rc >= 0 then return nil, rc end
	return errors.get(rc)
end


local function encode_signed(buf, n)
	local rc = C.sp_msgpack_enc_signed(buf, n)
	if rc >= 0 then return nil, rc end
	return errors.get(rc)
end


local function encode_unsigned(buf, n)
	local rc = C.sp_msgpack_enc_positive(buf, n)
	if rc >= 0 then return nil, rc end
	return errors.get(rc)
end


local function encode_double(buf, n)
	local rc = C.sp_msgpack_enc_double(buf, n)
	if rc >= 0 then return nil, rc end
	return errors.get(rc)
end


local function encode_string(buf, s)
	local rc = C.sp_msgpack_enc_string(buf, #s)
	if rc < 0 then return errors.get(rc) end
	C.memmove(buf + rc, s, #s)
	return nil, rc + #s
end


local function encode(data, buf)
	if not buf then
		buf = d.Buffer(4096)
	else
		-- TODO: this will continue to grow the buffer as needed. it'd be nice to
		-- instead yield out 4k bufs so they can be put on the wire immediately
		buf:ensure(4096)
	end

	local err, rc

	if type(data) == "table" then
		local n = 0
		for k, v in pairs(data) do n = n + 1 end
		if n == #data then
			-- this is an array
			err, rc = encode_array(buf:tail(), n)
			if err then return err end
			buf:bump(rc)
			for _, v in ipairs(data) do
				err, buf = encode(v, buf)
				if err then return err end
			end
		else
			-- this is a map
			err, rc = encode_map(buf:tail(), n)
			if err then return err end
			buf:bump(rc)
			for k, v in pairs(data) do
				err, buf = encode(k, buf)
				if err then return err end
				err, buf = encode(v, buf)
				if err then return err end
			end
		end

	elseif type(data) == "boolean" then
		if data then
			err, rc = encode_true(buf:tail(), data)
			if err then return err end
			buf:bump(rc)
		else
			err, rc = encode_false(buf:tail(), data)
			if err then return err end
			buf:bump(rc)
		end

	elseif type(data) == "string" then
		err, rc = encode_string(buf:tail(), data)
		if err then return err end
		buf:bump(rc)

	elseif type(data) == "number" then
		if math.floor(data) == data then
			err, rc = encode_signed(buf:tail(), data)
			if err then return err end
			buf:bump(rc)
		else
			err, rc = encode_double(buf:tail(), data)
			if err then return err end
			buf:bump(rc)
		end

	else
		error("TODO: " .. type(data))
	end

	return nil, buf
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


function Msgpack_mt:next(buf, len, eof)
	local rc = C.sp_msgpack_next(self, buf, len, eof)
	if rc >= 0 then return nil, rc end
	return errors.get(rc)
end


function Msgpack_mt:stream_next(stream)
	local buf, len = stream:value()

	local err, n = self:next(buf, len, false)
	if err then return err end

	if n > 0 then
		stream:trim(n)
		if self.type ~= C.SP_MSGPACK_NONE then
			return
		end
	end

	local err, n = stream:readin()
	if err then return err end
	return self:stream_next(stream)
end


function Msgpack_mt:stream_value(stream)
	local err = self:stream_next(stream)
	if err then return err end

	if self.type == C.SP_MSGPACK_MAP then
		local ob = {}
		local num = self.tag.count
		for _ = 1, num do
			local err, key = self:stream_value(stream)
			if err then return err end
			local err, value = self:stream_value(stream)
			if err then return err end
			ob[key] = value
		end
		return nil, ob

	elseif self.type == C.SP_MSGPACK_ARRAY then
		local num = self.tag.count
		local arr = {}
		for _ = 1, num do
			local err, value = self:stream_value(stream)
			if err then return err end
			table.insert(arr, value)
		end
		return nil, arr

	elseif self.type == C.SP_MSGPACK_SIGNED then
		return nil, tonumber(self.tag.i64)

	elseif self.type == C.SP_MSGPACK_UNSIGNED then
		return nil, tonumber(self.tag.i64)

	elseif self.type == C.SP_MSGPACK_FALSE then
		return nil, false

	elseif self.type == C.SP_MSGPACK_TRUE then
		return nil, true

	elseif self.type == C.SP_MSGPACK_DOUBLE then
		return nil, self.tag.f64

	elseif self.type == C.SP_MSGPACK_STRING then
		return nil, stream:take(self.tag.count)

	else
		error("TODO: "..tostring(self.type))
	end
end


function Msgpack_mt:stream(stream)
	-- stream methods:
	--	:readin()
	--	:value() -> returns char*, len (could return eof?)
	--	:trim(n)
	return self:stream_value(stream)
end


local decoder = ffi.metatype("SpMsgpack", Msgpack_mt)


return {
	encode = encode,
	decoder = decoder,
}
