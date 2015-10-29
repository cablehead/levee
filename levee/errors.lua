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
	local e = C.sp_error_next(self)
	if e ~= nil then return e end
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


local M = {}


M.get = function(code)
	local e = C.sp_error(code)
	if e ~= nil then return e end
end


M.get_eai = function(code)
	return M.get(C.sp_eai_code(code))
end


M.add = function(code, domain, name, msg)
	local e = C.sp_error_add(code, domain, name, msg)
	if e ~= nil then return e end
end


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


M.TIMEOUT = M.add(10100, "levee", "timeout", "operation timed out")
M.CLOSED = M.add(10101, "levee", "closed", "channel is closed")


return setmetatable(M, M_mt)
