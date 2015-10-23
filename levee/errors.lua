local ffi = require("ffi")
local C = ffi.C


local Error_mt = {}
Error_mt.__index = Error_mt


function Error_mt:__index(key)
	return self["_"..key]
end


function Error_mt:__tostring()
	return string.format(
		"%s error [%s]: %s (%s)\n",
		ffi.string(self.domain),
		self.code,
		ffi.string(self.name),
		ffi.string(self.msg))
end


ffi.metatype("SpError", Error_mt)


return {
	get = function(code)
		return C.sp_error(code)
	end,

	get_eai = function(code)
		return C.sp_error(C.sp_eai_code(code))
	end,

	add = function(code, domain, name, msg)
		return C.sp_error_add(code, domain, name, msg)
	end,
}
