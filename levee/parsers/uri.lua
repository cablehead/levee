local ffi = require('ffi')
local C = ffi.C

ffi.cdef[[
struct LeveeURI {
	SpUri base;
	SpRange16 rng;
};
]]


local module = {
	scheme = C.SP_URI_SCHEME,
	user = C.SP_URI_USER,
	password = C.SP_URI_PASSWORD,
	host = C.SP_URI_HOST,
	port = C.SP_URI_PORT,
	path = C.SP_URI_PATH,
	query = C.SP_URI_QUERY,
	fragment = C.SP_URI_FRAGMENT,
}


local URI
local URI_mt = {}
URI_mt.__index = URI_mt


function URI_mt:__tostring()
	return string.format("levee.parsers.URI: %p", self)
end


function URI_mt:parse(str, len)
	local len = C.sp_uri_parse(self.base, str, len or #str)
	return len >= 0
end


function URI_mt:sub(first, last, valid)
	local rc
	if valid then
		rc = C.sp_uri_sub(self.base, first, last, self.rng)
	else
		rc = C.sp_uri_range(self.base, first, last, self.rng)
	end
	if rc >= 0 then
		return
			tonumber(self.rng.off+1),
			tonumber(self.rng.off+self.rng.len)
	end
end


function URI_mt:segment(seg)
	if C.sp_uri_has_segment(self.base, seg) then
		return
			tonumber(self.base.seg[seg].off+1),
			tonumber(self.base.seg[seg].off+self.base.seg[seg].len)
	end
end


function URI_mt:join_parser(self_str, other_par, other_str)
	local out = URI()
	local len = #self_str + #other_str
	local buf = ffi.new("char [?]", len)

	len = C.sp_uri_join(
		out.base, buf, len,
		self.base, self_str,
		other_par.base, other_str)

	if len >= 0 then
		return out, ffi.string(ffi.cast("void *", buf), len)
	end
end


function URI_mt:join_string(self_str, other_str)
	local other_par = URI()
	if C.sp_uri_parse(other_par.base, other_str, #other_str) >= 0 then
		return self:join_parser(self_str, other_par, other_str)
	end
end


URI = ffi.metatype("struct LeveeURI", URI_mt)

module.URI = URI
return module
