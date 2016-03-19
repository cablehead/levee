local ffi = require("ffi")
local C = ffi.C


local Utf8_mt = {}
Utf8_mt.__index = Utf8_mt


function Utf8_mt:__gc()
	C.sp_utf8_final(self)
end


function Utf8_mt:init()
	C.sp_utf8_init(self)
end


local Utf8 = ffi.metatype("SpUtf8", Utf8_mt)


return {
	Utf8 = function()
		local self = Utf8()
		self:init()
		return self
	end
}
