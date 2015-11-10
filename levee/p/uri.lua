local ffi = require('ffi')
local C = ffi.C

ffi.cdef[[
struct LeveeURI {
	SpUri base;
	SpRange16 rng;
};
]]


local M = {
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


--[[
TODO: higher level URI functionality

local URI_mt = {}


local ranges = {
	userinfo = { uriparser.user, uriparser.password, false },
	authority = { uriparser.user, uriparser.port, false }
}


function URI_mt:__index(key)
	local i, j
	local id = uriparser[key]
	if id then
		i, j = self.parser:segment(id)
	else
		local rng = ranges[key]
		if not rng then error("invalid uri segment '"..key.."'", 2) end
		i, j = self.parser:sub(unpack(rng))
	end
	if i then
		local val = self.value:sub(i, j)
		self[key] = val
		return val
	end
end


function URI_mt:__tostring()
	return string.format("levee.URI: %s", self.value)
end


local function sub(self, first, last, valid)
	if type(first) == "string" then
		first = uriparser[first]
	end
	if not first then error("invalid first segment", 2) end

	if not last then
		last = uriparser.fragment
	elseif type(last) == "string" then
		last = uriparser[last]
		if not last then error("invalid last segment", 2) end
	end

	local i, j = self.parser:sub(first, last, valid)
	if i then
		return self.value:sub(i, j)
	end
end


local function join(self, other)
	local parser, value
	if type(other) == "string" then
		parser, value = self.parser:join_string(self.value, other)
	else
		parser, value = self.parser:join_parser(self.value, other.parser, other.value)
	end
	-- TODO: how should this error on bad URIs?
	if parser and value then
		return setmetatable({
			sub = sub,
			join = join,
			value = value,
			parser = out
		}, URI_mt)
	end
end


return function(str)
	local parser = uriparser.URI()
	if parser:parse(str) then
		return setmetatable({
			sub = sub,
			join = join,
			value = str,
			parser = parser
		}, URI_mt)
	end
end
--]]


M.URI = URI
return M
