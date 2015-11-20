local ffi = require("ffi")
local C = ffi.C

local errors = require("levee.errors")


local Json_mt = {}
Json_mt.__index = Json_mt


function Json_mt:__new()
	return ffi.new(self):init()
end


function Json_mt:__tostring()
	return string.format("levee.json: %p", self)
end


function Json_mt:init()
	C.sp_json_init(self)
	return self
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

	if n > 0 then
		stream:trim(n)
		-- need to read more if SP_JSON_NONE
		if self.type ~= C.SP_JSON_NONE then
			return
		end
	end

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

-- http://ericjmritz.name/2014/02/26/lua-is_array/
function is_array(t)
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end


local function encode(data)
	if type(data) == "table" then
		if is_array(data) then
			-- encode empty tables as dicts
			if #data == 0 then
				return "{}"
			end

			local ret = {}
			table.insert(ret, "[")
			for i, item in ipairs(data) do
					table.insert(ret, encode(item))
					table.insert(ret, ", ")
			end
			table.remove(ret)  -- pop trailing ','
			table.insert(ret, "]")
			return table.concat(ret)

		else
			-- dict
			local ret = {}
			table.insert(ret, "{")
			if next(data) then
				for key, value in pairs(data) do
					assert(type(key) == "string")
					table.insert(ret, '"'..key..'"')
					table.insert(ret, ": ")
					table.insert(ret, encode(value))
					table.insert(ret, ", ")
				end
				table.remove(ret)  -- pop trailing ','
			end
			table.insert(ret, "}")
			return table.concat(ret)
	end

	elseif type(data) == "string" then
		return '"'.. data:gsub("\n", "\\n") ..'"'

	elseif type(data) == "number" then
		return tostring(data)

	else
		print(type(data))
		assert(false)
	end
end

local decoder = ffi.metatype("SpJson", Json_mt)

local M = {
	decoder = decode,
	encode = encode,
}

function M.decode(s)
	return decoder():stream(M.StringStream(s))
end

return M

