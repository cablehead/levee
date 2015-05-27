local ffi = require("ffi")
local C = ffi.C


local HTTPParser = {}
HTTPParser.__index = HTTPParser


function HTTPParser:__new()
	return ffi.new(self)
end


function HTTPParser:__tostring()
	return string.format("levee.HTTPParser: ")
end


function HTTPParser:init_request()
	return C.http_parser_init_request(self)
end


function HTTPParser:init_response()
	return C.http_parser_init_response(self)
end


function HTTPParser:next(buf, len)
	return C.http_parser_next(self, buf, len)
end

function HTTPParser:is_done()
	return C.http_parser_is_done(self)
end


function HTTPParser:value(buf)
	if self.type == C.HTTP_PARSER_REQUEST then
		return
			ffi.string(
				buf + self.as.request.method_off, self.as.request.method_len),
			ffi.string(buf + self.as.request.uri_off, self.as.request.uri_len),
			self.as.request.version
	elseif self.type == C.HTTP_PARSER_RESPONSE then
		return
			self.as.response.status,
			ffi.string(
				buf + self.as.response.reason_off, self.as.response.reason_len),
			self.as.request.version
	elseif self.type == C.HTTP_PARSER_FIELD then
		return
			ffi.string(buf + self.as.field.name_off, self.as.field.name_len),
			ffi.string(buf + self.as.field.value_off, self.as.field.value_len)
	elseif self.type == C.HTTP_PARSER_BODY_START then
		return
			self.as.body_start.chunked,
			self.as.body_start.content_length
	elseif self.type == C.HTTP_PARSER_BODY_CHUNK then
		return
			true,
			self.as.body_chunk.length
	elseif self.type == C.HTTP_PARSER_BODY_END then
		return
			false,
			0
	end
end


return ffi.metatype("HTTPParser", HTTPParser)
