local ffi = require("ffi")
local C = ffi.C


local Error_mt = {}


function Error_mt:__tostring()
	return string.format(
		"%s error [%s]: %s (%s)\n", self.domain, self.code, self.name, self.msg)
end


function Error_mt:is(domain, name)
	return self.domain == domain and self.name == name
end


function Error_mt:next()
	return C.sp_error_next(self)
end


function Error_mt:__index(key)
	local fields = {
		code = tonumber,
		domain = ffi.string,
		name = ffi.string,
		msg = ffi.string, }

	if fields[key] then
		return fields[key](self["_"..key])
	end

	local domain, name = key:match("is_([a-zA-Z0-9]+)_([a-zA-Z0-9]+)")
	if domain and name then return self:is(domain, name) end

	return Error_mt[key]
end


ffi.metatype("SpError", Error_mt)


local M = {
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


local M_mt = {
	__call = function()
		local e
		return function()
			if not e then
				e = M.get(-1)
			else
				e = e:next()
			end
			return e
		end
	end,
}


return setmetatable(M, M_mt)
