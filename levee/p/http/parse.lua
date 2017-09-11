local ffi = require('ffi')
local C = ffi.C

local errors = require("levee.errors")


local Parser_mt = {}
Parser_mt.__index = Parser_mt


function Parser_mt:__new()
	return ffi.new(self)
end


function Parser_mt:__tostring()
	return string.format(
		"levee.http.Parser: %s", self.response and "response" or "request")
end


function Parser_mt:init_request(config)
	C.sp_http_init_request(self, false)
	self:config(config)
end


function Parser_mt:init_response(config)
	C.sp_http_init_response(self, false)
	self:config(config)
end


function Parser_mt:reset()
	C.sp_http_reset(self)
end


function Parser_mt:config(t)
	if type(t) ~= "table" then return end
	if t.max_method then self.max_method = t.max_method end
	if t.max_uri then self.max_uri = t.max_uri end
	if t.max_reason then self.max_reason = t.max_reason end
	if t.max_field then self.max_field = t.max_field end
	if t.max_value then self.max_value = t.max_value end
end


function Parser_mt:next(buf, len)
	local rc = C.sp_http_next(self, buf, len)
	if rc >= 0 then
		return nil, rc
	end
	return errors.get(rc)
end


function Parser_mt:is_done()
	return C.sp_http_is_done(self)
end


function Parser_mt:has_value()
	return
		self.type == C.SP_HTTP_REQUEST or
		self.type == C.SP_HTTP_RESPONSE or
		self.type == C.SP_HTTP_FIELD or
		self.type == C.SP_HTTP_BODY_START or
		self.type == C.SP_HTTP_BODY_CHUNK
end


function Parser_mt:value(buf)
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


function Parser_mt:stream_next(stream)
	local err, n = self:next(stream:value())
	if err then return err end

	if n > 0 then
		local value = {self:value(stream:value())}
		stream:trim(n)
		if self:is_done() then
			self:reset()
		end
		return nil, value
	end

	local err, n = stream:readin()
	if err then
		if err == errors.CLOSED then
			return errors.http.ESYNTAX
		end
		return err
	end
	return self:stream_next(stream)
end



return ffi.metatype("SpHttp", Parser_mt)
