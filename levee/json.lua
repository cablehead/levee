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
	if n < 0 then error(("parse error: %s"):format(self)) end

	if n > 0 then
		buf:trim(n)
		-- need to read more if SP_JSON_NONE
		if self.type ~= C.SP_JSON_NONE then
			return
		end
	end

	local n, err = conn:readinto(buf)
	assert(n > 0)

	return self:stream_next(conn, buf)
end


function Json_mt:stream_consume(conn, buf)
	self:stream_next(conn, buf)

	if self.type == C.SP_JSON_OBJECT then
		local ob = {}
		while true do
			local key = self:stream_consume(conn, buf)
			if key == C.SP_JSON_OBJECT_END then
				return ob
			end
			ob[key] = self:stream_consume(conn, buf)
		end

	elseif self.type == C.SP_JSON_ARRAY then
		local arr = {}
		while true do
			local item = self:stream_consume(conn, buf)
			if item == C.SP_JSON_ARRAY_END then
				return arr
			end
			table.insert(arr, item)
		end

	elseif self.type == C.SP_JSON_NUMBER then
		return self.number

	elseif self.type == C.SP_JSON_STRING then
		return ffi.string(self.utf8.buf, self.utf8.len)

	elseif self.type == C.SP_JSON_TRUE then
		return true

	elseif self.type == C.SP_JSON_FALSE then
		return false

	else
		return self.type
	end
end


return ffi.metatype("SpJson", Json_mt)
