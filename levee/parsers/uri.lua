local ffi = require('ffi')
local C = ffi.C

ffi.cdef[[
struct LeveeURI {
	SpUri base;
	SpRange16 rng;
};
]]


local names = {
	scheme = C.SP_URI_SCHEME,
	user = C.SP_URI_USER,
	password = C.SP_URI_PASSWORD,
	host = C.SP_URI_HOST,
	port = C.SP_URI_PORT,
	path = C.SP_URI_PATH,
	query = C.SP_URI_QUERY,
	fragment = C.SP_URI_FRAGMENT,
}


local URI_mt = {}
URI_mt.__index = URI_mt


function URI_mt:__tostring()
	return string.format("levee.parsers.URI: %p", self)
end


function URI_mt:parse(str, len)
	local len = C.sp_uri_parse(self.base, str, len or #str)
	return len > 0
end


function URI_mt:sub(first, last)
	if not first then
		first = C.SP_URI_SEGMENT_FIRST
		last = C.SP_URI_SEGMENT_LAST
	elseif not last then
		if type(first) == "string" then
			first = names[first]
		end
		if C.sp_uri_range(self.base, first, first, self.rng) == 0 then
			return tonumber(self.rng.off+1), tonumber(self.rng.off+self.rng.len)
		end
	else
		if type(first) == "string" then
			first = names[first]
		end
		if type(last) == "string" then
			last = names[last]
		end
	end
	if C.sp_uri_sub(self.base, first, last, self.rng) == 0 then
		return tonumber(self.rng.off+1), tonumber(self.rng.off+self.rng.len)
	end
end


local URI = ffi.metatype("struct LeveeURI", URI_mt)

return URI
