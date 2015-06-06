local ffi = require("ffi")
local C = ffi.C


local HTTPParser = {}
HTTPParser.__index = HTTPParser


function HTTPParser:__new()
	return ffi.new(self)
end


function HTTPParser:__tostring()
	return string.format(
		"levee.HTTPParser: %s", self.response and "response" or "request")
end


function HTTPParser:init_request()
	return C.np_http_init_request(self)
end


function HTTPParser:init_response()
	return C.np_http_init_response(self)
end


function HTTPParser:reset()
	return C.np_http_reset(self)
end


function HTTPParser:next(buf, len)
	return C.np_http_next(self, buf, len)
end

function HTTPParser:is_done()
	return C.np_http_is_done(self)
end


function HTTPParser:has_value()
	return
		self.type == C.NP_HTTP_REQUEST or
		self.type == C.NP_HTTP_RESPONSE or
		self.type == C.NP_HTTP_FIELD or
		self.type == C.NP_HTTP_BODY_START or
		self.type == C.NP_HTTP_BODY_CHUNK
end


function HTTPParser:value(buf)
	if self.type == C.NP_HTTP_REQUEST then
		return
			ffi.string(
				buf + self.as.request.method_off, self.as.request.method_len),
			ffi.string(buf + self.as.request.uri_off, self.as.request.uri_len),
			self.as.request.version
	elseif self.type == C.NP_HTTP_RESPONSE then
		return
			self.as.response.status,
			ffi.string(
				buf + self.as.response.reason_off, self.as.response.reason_len),
			self.as.request.version
	elseif self.type == C.NP_HTTP_FIELD then
		return
			ffi.string(buf + self.as.field.name_off, self.as.field.name_len),
			ffi.string(buf + self.as.field.value_off, self.as.field.value_len)
	elseif self.type == C.NP_HTTP_BODY_START then
		return
			false,
			self.as.body_start.chunked,
			self.as.body_start.content_length
	elseif self.type == C.NP_HTTP_BODY_CHUNK then
		return
			true,
			self.as.body_chunk.length
	elseif self.type == C.NP_HTTP_BODY_END then
		return
			false,
			0
	end
end


local allocate = ffi.metatype("NpHttp", HTTPParser)


return {
	Request = function()
		local p = allocate()
		p:init_request()
		return p
	end,

	Response = function()
		local p = allocate()
		p:init_response()
		return p
	end,
}
