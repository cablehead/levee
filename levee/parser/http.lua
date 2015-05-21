local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
typedef struct {
	HTTPParser p;
	HTTPValue val;
} LeveeHTTPParser;
]]


local HTTPParser = {}
HTTPParser.__index = HTTPParser


function HTTPParser:__new()
	return ffi.new(self)
end


function HTTPParser:__tostring()
	return string.format("levee.HTTPParser: ")
end


function HTTPParser:init_request()
	return C.http_parser_init_request(self.p)
end


function HTTPParser:next(buf, len)
	return C.http_parser_next(self.p, self.val, buf, len)
end


function HTTPParser:is_done()
	return C.http_parser_is_done(self.p)
end


function HTTPParser:value(buf)
	if self.val.type == C.HTTP_PARSER_REQUEST then
		return
			ffi.string(
				buf + self.val.as.request.method_off, self.val.as.request.method_len),
			ffi.string(buf + self.val.as.request.uri_off, self.val.as.request.uri_len),
			self.val.as.request.version
	elseif self.val.type == C.HTTP_PARSER_HEADER_FIELD then
		return
			ffi.string(buf + self.val.as.field.name_off, self.val.as.field.name_len),
			ffi.string(buf + self.val.as.field.value_off, self.val.as.field.value_len)
	elseif self.val.type == C.HTTP_PARSER_HEADER_END then
		return false
	elseif self.val.type == C.HTTP_PARSER_BODY then
		return
			ffi.string(buf + self.val.as.body.value_off, self.val.as.body.value_len)
	end
end


return ffi.metatype("LeveeHTTPParser", HTTPParser)
