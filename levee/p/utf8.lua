local ffi = require("ffi")
local C = ffi.C


local Utf8_mt = {}
Utf8_mt.__index = Utf8_mt


function Utf8_mt:__gc()
	C.sp_utf8_final(self)
end


function Utf8_mt:_init()
	C.sp_utf8_init(self)
end


function Utf8_mt:encode(buf, len)
	return C.sp_utf8_encode(self, buf, len or #buf, C.SP_UTF8_NONE)
end


function Utf8_mt:decode(buf, len)
	return C.sp_utf8_decode(self, buf, len, C.SP_UTF8_NONE)
end


function Utf8_mt:peek()
	return ffi.string(self.buf, self.len)
end


local Utf8 = ffi.metatype("SpUtf8", Utf8_mt)


return {
	Utf8 = function()
		local self = Utf8()
		self:_init()
		return self
	end,

	charlen = function(buf, len)
		return C.sp_utf8_charlen(buf, len or #buf)
	end,
}
