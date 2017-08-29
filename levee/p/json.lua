local ffi = require("ffi")
local C = ffi.C

local errors = require("levee.errors")
local _ = require("levee._")
local d = require("levee.d")
local utf8 = require("levee.p.utf8")


local __utf8_encoder


local function utf8_encode(buf, s, pad)
	if not __utf8_encoder then __utf8_encoder = utf8.Utf8.new() end
	buf:ensure(math.ceil(#s * pad))
	__utf8_encoder:init_fixed(buf:tail())
	local err, n = __utf8_encoder:encode(s, #s, C.SP_UTF8_JSON)
	__utf8_encoder:final()
	return err, n
end


local Json_mt = {}
Json_mt.__index = Json_mt


function Json_mt:__new()
	return ffi.new(self):init()
end


function Json_mt:__tostring()
	local type_map = {
		[C.SP_JSON_NONE] = "NONE",
		[C.SP_JSON_OBJECT] = "OBJECT",
		[C.SP_JSON_ARRAY] = "ARRAY",
		[C.SP_JSON_OBJECT_END] = "OBJECT_END",
		[C.SP_JSON_ARRAY_END] = "ARRAY_END",
		[C.SP_JSON_TRUE] = "TRUE",
		[C.SP_JSON_FALSE] = "FALSE",
		[C.SP_JSON_STRING] = "STRING",
		[C.SP_JSON_NUMBER] = "NUMBER",
		[C.SP_JSON_NULL] = "NULL", }
	return string.format(
		"levee.p.json: %p type=%s", self, type_map[tonumber(self.type)])
end


function Json_mt:init()
	C.sp_json_init(self)
	return self
end


function Json_mt:__gc()
	C.sp_json_final(self)
end


function Json_mt:reset()
	C.sp_json_reset(self)
end


function Json_mt:is_done()
	return C.sp_json_is_done(self)
end


function Json_mt:next(buf, len, eof)
	local rc = C.sp_json_next(self, buf, len, eof)
	if rc >= 0 then return nil, rc end
	return errors.get(rc)
end


function Json_mt:stream_next(stream)
	local buf, len = stream:value()

	local err, n = self:next(buf, len, false)
	if err then return err end

	if n > 0 then stream:trim(n) end
	if self.type ~= C.SP_JSON_NONE then return end

	local err, n = stream:readin()
	if err then return err end

	return self:stream_next(stream)
end


function Json_mt:stream_value(stream)
	local err = self:stream_next(stream)
	if err then return err end

	if self.type == C.SP_JSON_OBJECT then
		local ob = {}
		while true do
			local err, key = self:stream_value(stream)
			if err then return err end
			if key == C.SP_JSON_OBJECT_END then return nil, ob end
			local err, value = self:stream_value(stream)
			if err then return err end
			ob[key] = value
		end

	elseif self.type == C.SP_JSON_ARRAY then
		local arr = {}
		while true do
			local err, item = self:stream_value(stream)
			if err then return err end
			if item == C.SP_JSON_ARRAY_END then return nil, arr end
			table.insert(arr, item)
		end

	elseif self.type == C.SP_JSON_NUMBER then
		return nil, self.number

	elseif self.type == C.SP_JSON_STRING then
		return nil, ffi.string(self.utf8.buf, self.utf8.len)

	elseif self.type == C.SP_JSON_TRUE then
		return nil, true

	elseif self.type == C.SP_JSON_FALSE then
		return nil, false

	elseif self.type == C.SP_JSON_NULL then
		return nil, nil

	else
		-- should only be SP_JSON_OBJECT_END and SP_JSON_ARRAY_END
		return nil, self.type
	end
end


function Json_mt:stream(stream)
	-- stream methods:
	--	:readin()
	--	:value() -> returns char*, len (could return eof?)
	--	:trim(n)
	local err, value = self:stream_value(stream)
	if err then return err end
	assert(self:is_done())
	self:reset()
	return nil, value
end


--
-- Poor man's encode - just awful, please replace

local function encode(data, buf)
	if not buf then
		buf = d.Buffer(4096)
	end

	if type(data) == "table" then
		if _.is_array(data) then
			-- encode empty tables as dicts
			if #data == 0 then
				buf:push("{}")
				return nil, buf
			end

			local ret = {}
			buf:push("[")
			for i, item in ipairs(data) do
				local err = encode(item, buf)
				if err then return err end
				buf:push(", ")
			end
			buf.len = buf.len - 2  -- pop trailing ','
			buf:push("]")
			return nil, buf

		else
			-- dict
			local ret = {}
			buf:push("{")
			if next(data) then
				for key, value in pairs(data) do
					assert(type(key) == "string")
					-- TODO: memcpy
					buf:push('"')
					buf:push(key)
					buf:push('": ')
					local err = encode(value, buf)
					if err then return err end
					buf:push(", ")
				end
				buf.len = buf.len - 2  -- pop trailing ','
			end
			buf:push("}")
			return nil, buf
		end

	elseif type(data) == "string" then
		buf:push('"')
		local err, n
		err, n = utf8_encode(buf, data, 1.2)
		if err then
			-- pathological case?
			err, n = utf8_encode(buf, data, 2)
			if err then return err end
		end
		buf:bump(n)
		buf:push('"')
		return nil, buf

	elseif type(data) == "number" or type(data) == "boolean" then
		buf:push(tostring(data))
		return nil, buf

	else
		print(type(data))
		assert(false)
	end
end


local decoder = ffi.metatype("SpJson", Json_mt)

local M = {
	decoder = decoder,
	-- TODO:
	-- should be able to encode to an iovec
	encode = encode,
}

function M.decode(s, len)
	return decoder():stream(M.StringStream(s, len))
end


-- io conveniences, still sketching
local P_mt = {}
P_mt.__index = P_mt


function P_mt:read()
	return self.decoder:stream(self.p)
end


function P_mt:write(data)
	local err = M.encode(data, self.p.wbuf)
	if err then return err end
	local err, n = self.p.io:write(self.p.wbuf:value())
	self.p.wbuf:trim()
	return err, n
end


function M.io(p)
	return setmetatable({p=p, decoder=M.decoder()}, P_mt)
end


return M
