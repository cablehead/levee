local uriparser = require("levee.parsers.uri")


local URI_mt = {}


local ranges = {
	userinfo = { uriparser.user, uriparser.password, false },
	netloc = { uriparser.user, uriparser.port, false }
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
