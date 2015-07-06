local ffi = require("ffi")
local C = ffi.C


local HTTP_mt = {}
HTTP_mt.__index = HTTP_mt


function HTTP_mt:__new()
	return ffi.new(self)
end


function HTTP_mt:__tostring()
	return string.format(
		"levee.parsers.HTTP: %s", self.response and "response" or "request")
end


function HTTP_mt:init_request()
	return C.sp_http_init_request(self)
end


function HTTP_mt:init_response()
	return C.sp_http_init_response(self)
end


function HTTP_mt:reset()
	return C.sp_http_reset(self)
end


function HTTP_mt:next(buf, len)
	return C.sp_http_next(self, buf, len)
end

function HTTP_mt:is_done()
	return C.sp_http_is_done(self)
end


function HTTP_mt:has_value()
	return
		self.type == C.SP_HTTP_REQUEST or
		self.type == C.SP_HTTP_RESPONSE or
		self.type == C.SP_HTTP_FIELD or
		self.type == C.SP_HTTP_BODY_START or
		self.type == C.SP_HTTP_BODY_CHUNK
end


function HTTP_mt:value(buf)
	if self.type == C.SP_HTTP_REQUEST then
		return
			ffi.string(
				buf + self.as.request.method_off, self.as.request.method_len),
			ffi.string(buf + self.as.request.uri_off, self.as.request.uri_len),
			self.as.request.version
	elseif self.type == C.SP_HTTP_RESPONSE then
		return
			self.as.response.status,
			ffi.string(
				buf + self.as.response.reason_off, self.as.response.reason_len),
			self.as.request.version
	elseif self.type == C.SP_HTTP_FIELD then
		return
			ffi.string(buf + self.as.field.name_off, self.as.field.name_len),
			ffi.string(buf + self.as.field.value_off, self.as.field.value_len)
	elseif self.type == C.SP_HTTP_BODY_START then
		return
			false,
			self.as.body_start.chunked,
			self.as.body_start.content_length
	elseif self.type == C.SP_HTTP_BODY_CHUNK then
		return
			true,
			self.as.body_chunk.length
	elseif self.type == C.SP_HTTP_BODY_END then
		return
			false,
			0
	end
end


local allocate = ffi.metatype("SpHttp", HTTP_mt)


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
