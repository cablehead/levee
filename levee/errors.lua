local ffi = require("ffi")
local C = ffi.C


local Error_mt = {}


function Error_mt:__tostring()
	return string.format(
		"%s (%s.%s)", self.msg, self.domain, self.name)
end


function Error_mt:is(domain, name)
	return self.domain == domain and self.name == name
end


function Error_mt:exit(code)
	C.sp_exit(self.code, code or 1)
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


M.TIMEOUT = M.add(10100, "levee", "TIMEOUT", "operation timed out")
M.CLOSED = M.add(10101, "levee", "CLOSED", "channel is closed")


local err = nil
while true do
	err = C.sp_error_next(err)
	if err == nil then
		break
	end
	if not M[err.domain] then
		M[err.domain] = {}
	end
	M[err.domain][err.name] = err
end


return M
