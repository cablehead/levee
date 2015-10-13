local ffi = require("ffi")
local C = ffi.C

local errno = require("levee.errno")
local buffer = require("levee.buffer")


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
	if not buf then buf = buffer(4096) end

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

return {
	encode = encode,
}
