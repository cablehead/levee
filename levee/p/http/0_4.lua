local ffi = require('ffi')
local C = ffi.C
local meta = require("levee.meta")
local UTF8 = require("levee.p.utf8").Utf8


local VERSION = "HTTP/1.1"
local FIELD_SEP = ": "
local CRLF = "\r\n"

local USER_AGENT = ("%s/%s"):format(meta.name, meta.version.string)


function encode_headers(headers)
	-- TODO: Host
	local ret = {
		["User-Agent"] = USER_AGENT,
		Accept = "*/*", }
	for key, value in pairs(headers or {}) do
		ret[key] = value
	end
	return ret
end


-- TODO make this part of levee.p.uri when it makes sense
local function encode_url(value)
	local buf = ffi.cast("char *", value)
	local u = UTF8()
	local flag = bit.bor(C.SP_UTF8_URI, C.SP_UTF8_SPACE_PLUS)
	local n = u:encode(buf, #value, flag)
	return ffi.string(u.buf, n)
end


function encode_request(method, path, params, headers, data, buf)
	if params then
		local s = {path, "?"}
		for key, value in pairs(params) do
			table.insert(s, key)
			table.insert(s, "=")
			table.insert(s, value)
			table.insert(s, "&")
		end
		table.remove(s)
		path = table.concat(s)
	end
	path = encode_url(path)

	buf:push(("%s %s %s%s"):format(method, path, VERSION, CRLF))
	if err then return err end

	headers = encode_headers(headers)
	if data then
		headers["Content-Length"] = tostring(#data)
	end

	for k, v in pairs(headers) do
		if type(v) == "table" then
			for _,item in pairs(v) do
				buf:push(k..FIELD_SEP..item..CRLF)
				if err then return err end
			end
		else
			buf:push(k..FIELD_SEP..v..CRLF)
			if err then return err end
		end
	end
	buf:push(CRLF)

	if data then
		local err = buf:push(data)
		if err then return err end
	end
end

return {
	encode_request=encode_request,
}
