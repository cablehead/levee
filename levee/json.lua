local ffi = require("ffi")
local C = ffi.C


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


function Json_mt:next(eof, buf, len)
	return C.sp_json_next(self, buf, len, eof)
end


function Json_mt:stream_next(conn, buf)
	local n = self:next(false, buf:value())
	if n < 0 then
		return false, "parse error"
	end

	if n > 0 then
		buf:trim(n)
		-- need to read more if SP_JSON_NONE
		if self.type ~= C.SP_JSON_NONE then
			return true
		end
	end

	local n, err = conn:readinto(buf)
	if n <= 0 then
		-- connection died
		return false
	end

	return self:stream_next(conn, buf)
end


function Json_mt:stream_value(conn, buf)
	if not self:stream_next(conn, buf) then
		return
	end

	if self.type == C.SP_JSON_OBJECT then
		local ob = {}
		while true do
			local ok, key = self:stream_value(conn, buf)
			if not ok then return end
			if key == C.SP_JSON_OBJECT_END then
				return true, ob
			end
			local ok, value = self:stream_value(conn, buf)
			if not ok then return end
			ob[key] = value
		end

	elseif self.type == C.SP_JSON_ARRAY then
		local arr = {}
		while true do
			local ok, item = self:stream_value(conn, buf)
			if not ok then return end
			if item == C.SP_JSON_ARRAY_END then
				return true, arr
			end
			table.insert(arr, item)
		end

	elseif self.type == C.SP_JSON_NUMBER then
		return true, self.number

	elseif self.type == C.SP_JSON_STRING then
		return true, ffi.string(self.utf8.buf, self.utf8.len)

	elseif self.type == C.SP_JSON_TRUE then
		return true, true

	elseif self.type == C.SP_JSON_FALSE then
		return true, false

	else
		-- should only be SP_JSON_OBJECT_END and SP_JSON_ARRAY_END
		return true, self.type
	end
end


function Json_mt:stream_consume(conn, buf)
	local ok, value = self:stream_value(conn, buf)
	if not ok then return end
	assert(self:is_done())
	self:reset()
	return true, value
end


return ffi.metatype("SpJson", Json_mt)
