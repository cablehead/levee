local ffi = require('ffi')
local C = ffi.C
local errors = require("levee.errors")


local URIParser = ffi.typeof("struct { SpUri par; SpRange16 rng; }")
local URIBuffer = ffi.typeof("struct { char val[8184]; size_t len[1]; }")


local tmp_key = URIBuffer()
local tmp_val = URIBuffer()


local segments = {
	scheme = C.SP_URI_SCHEME,
	user = C.SP_URI_USER,
	password = C.SP_URI_PASSWORD,
	host = C.SP_URI_HOST,
	port = C.SP_URI_PORT,
	path = C.SP_URI_PATH,
	query = C.SP_URI_QUERY,
	fragment = C.SP_URI_FRAGMENT,
}


local ranges = {
	userinfo = { segments.user, segments.password, false },
	authority = { segments.user, segments.port, false },
	hierarch = { segments.user, segments.path, false },
	request = { segments.path, segments.query, true },
}


local URI_mt = {}


function URI_mt:__index(key)
	local i, j
	local id = segments[key]
	local p = self.parser
	if id then
		if not C.sp_uri_has_segment(p.par, id) then return end
		i = tonumber(p.par.seg[id].off+1)
		j = tonumber(p.par.seg[id].off+p.par.seg[id].len)
	else
		local rng = ranges[key]
		if not rng then return end
		local rc
		if rng[3] then
			rc = C.sp_uri_sub(p.par, rng[1], rng[2], p.rng)
		else
			rc = C.sp_uri_range(p.par, rng[1], rng[2], p.rng)
		end
		if rc < 0 then return end
		i = tonumber(p.rng.off+1)
		j = tonumber(p.rng.off+p.rng.len)
	end
	local val = self.value:sub(i, j)
	self[key] = val
	return val
end


function URI_mt:__tostring()
	return self.value
end


local function sub(self, first, last, valid)
	if type(first) == "string" then first = segments[first] end
	if not first then return end

	if not last or type(last) == "boolean" then
		valid = last
		last = first
	elseif type(last) == "string" then
		last = segments[last]
		if not last then return end
	end

	local rc
	if valid then
		rc = C.sp_uri_sub(self.parser.par, first, last, self.parser.rng)
	else
		rc = C.sp_uri_range(self.parser.par, first, last, self.parser.rng)
	end
	if rc < 0 then return end

	return self.value:sub(
		tonumber(self.parser.rng.off+1),
		tonumber(self.parser.rng.off+self.parser.rng.len))
end


local function join(self, other)
	local other_str, other_par
	if type(other) == "string" then
		other_str = other
		other_par = URIParser()
		local rc = C.sp_uri_parse(other_par.par, other_str, #other_str)
		if rc < 0 then return errors.uri.ESYNTAX end
	else
		other_str = other.value
		other_par = other.parser
	end

	local parser = URIParser()
	local len = #self.value + #other_str
	local buf = ffi.new("char [?]", len)

	len = C.sp_uri_join(
		parser.par, buf, len,
		self.parser.par, self.value,
		other_par.par, other_str)

	if len < 0 then return errors.get(len) end
	return nil, setmetatable({
		sub = sub,
		join = join,
		value = ffi.string(buf, len),
		parser = out
	}, URI_mt)
end


local function params(self)
	if self._params then return nil, self._params end

	local t = {}
	local rng = self.parser.par.seg[C.SP_URI_QUERY]
	local p = ffi.cast("const char *", self.value) + rng.off
	local len = rng.len
	local rc

	while len > 0 do
		tmp_key.len[0] = ffi.sizeof(tmp_key.val)
		tmp_val.len[0] = ffi.sizeof(tmp_val.val)
		rc = C.sp_uri_query_next(p, len,
				tmp_key.val, tmp_key.len,
				tmp_val.val, tmp_val.len)
		if rc < 0 then return errors.get(rc) end

		local key = ffi.string(tmp_key.val, tmp_key.len[0])
		local val = ffi.string(tmp_val.val, tmp_val.len[0])
		local cur = t[key]
		if type(cur) == "string" then
			val = {cur, val}
		elseif type(cur) == "table" then
			table.insert(cur, val)
			val = cur
		end
		t[key] = val
		p = p + rc
		len = len - rc
	end

	self._params = t
	return nil, t
end


local M_mt = {
	SCHEME = C.SP_URI_SCHEME,
	USER = C.SP_URI_USER,
	PASSWORD = C.SP_URI_PASSWORD,
	HOST = C.SP_URI_HOST,
	PORT = C.SP_URI_PORT,
	PATH = C.SP_URI_PATH,
	QUERY = C.SP_URI_QUERY,
	FRAGMENT = C.SP_URI_FRAGMENT
}
M_mt.__index = M_mt


function M_mt:__call(str)
	local parser = URIParser()
	local rc = C.sp_uri_parse(parser.par, str, #str)
	if rc < 0 then return errors.uri.ESYNTAX end
	return nil, setmetatable({
		sub = sub,
		join = join,
		params = params,
		value = str,
		parser = parser
	}, URI_mt)
end


return setmetatable({}, M_mt)
