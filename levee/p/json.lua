local ffi = require("ffi")
local C = ffi.C

local errors = require("levee.errors")
local _ = require("levee._")
local d = require("levee.d")


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
				return buf
			end

			local ret = {}
			buf:push("[")
			for i, item in ipairs(data) do
				encode(item, buf)
				buf:push(", ")
			end
			buf.len = buf.len - 2  -- pop trailing ','
			buf:push("]")
			return buf

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
					encode(value, buf)
					buf:push(", ")
				end
				buf.len = buf.len - 2  -- pop trailing ','
			end
			buf:push("}")
			return buf
		end

	elseif type(data) == "string" then
		buf:push('"')
		buf:push(data:gsub("\n", "\\n"))
		buf:push('"')
		return buf

	elseif type(data) == "number" or type(data) == "boolean" then
		buf:push(tostring(data))
		return buf

	else
		print(type(data))
		assert(false)
	end
end

local decoder = ffi.metatype("SpJson", Json_mt)

local M = {
	decoder = decoder,
	-- TODO:
	encode = function(t)
		return nil, encode(t)
	end,
}

function M.decode(s, len)
	return decoder():stream(M.StringStream(s, len))
end


return M
