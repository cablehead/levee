local ffi = require("ffi")
local C = ffi.C

local errors = require("levee.errors")


local Utf8_mt = {}
Utf8_mt.__index = Utf8_mt


function Utf8_mt:__gc()
	C.sp_utf8_final(self)
end


function Utf8_mt:_init()
	C.sp_utf8_init(self)
end


function Utf8_mt:_init_fixed(buf, len)
	C.sp_utf8_init_fixed(self, buf, len)
end


function Utf8_mt:encode(buf, len, mode)
	local rc = C.sp_utf8_encode(self, buf, len or #buf, mode or C.SP_UTF8_NONE)
	if rc >= 0 then return nil, rc end
	return errors.get(rc)
end


function Utf8_mt:decode(buf, len)
	local rc = C.sp_utf8_decode(self, buf, len, C.SP_UTF8_NONE)
	if rc >= 0 then return nil, rc end
	return errors.get(rc)
end


function Utf8_mt:peek()
	return ffi.string(self.buf, self.len)
end


local Utf8 = {}
Utf8.__index = Utf8


Utf8.new = ffi.metatype("SpUtf8", Utf8_mt)


function Utf8.__call()
	local self = Utf8.new()
	self:_init()
	return self
end


function Utf8.from_fixed(buf, len)
	local self = Utf8.new()
	self:_init_fixed(buf, len)
	return self
end


return {
	Utf8 = setmetatable({}, Utf8),

	charlen = function(buf, len)
		return C.sp_utf8_charlen(buf, len or #buf)
	end,
}
