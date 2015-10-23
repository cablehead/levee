local ffi = require('ffi')
local C = ffi.C


local errors = require("levee.errors")


local _ = {}


_.dirname = function(s)
	if s:match(".-/.-") then
		return string.gsub(s, "(.*/)(.*)", "%1"):gsub("/$", "")
	end
	return ''
end


_.basename = function(s)
	local name = string.gsub(s, "(.*/)(.*)", "%2")
	return name
end


_.procname = function()
	local buf = ffi.new("char[?]", 4096)
	local n = C.sp_path_proc(buf, 4096)
	if n < 0 then return errors.get(ffi.errno()) end
	return nil, ffi.string(buf, n)
end


return _
