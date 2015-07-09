local ffi = require('ffi')
local C = ffi.C

ffi.cdef[[
struct LeveeData {
	const void *val;
	size_t len;
};
]]


local Data_mt = {}
Data_mt.__index = Data_mt


function Data_mt:__new(val, len)
	return ffi.new(self, val, len)
end


function Data_mt:__gc()
	C.free(ffi.cast("void *", self.val))
end


function Data_mt:__tostring()
	return string.format("levee.Data: val=%p, len=%u", self.val, tonumber(self.len))
end


function Data_mt:__len()
	return self.len
end


function Data_mt:value()
	return self.val, self.len
end


return ffi.metatype("struct LeveeData", Data_mt)
