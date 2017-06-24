local meta = require("levee.meta")


local VERSION = "HTTP/1.1"
local FIELD_SEP = ": "
local CRLF = "\r\n"

local USER_AGENT = ("%s/%s"):format(meta.name, meta.version.string)


function __headers(headers)
	-- TODO: Host
	local ret = {
		["User-Agent"] = USER_AGENT,
		Accept = "*/*", }
	for key, value in pairs(headers or {}) do
		ret[key] = value
	end
	return ret
end


function encode_request(method, path, params, headers, data, buf)
	-- TODO: url encode params
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

	buf:push(("%s %s %s%s"):format(method, path, VERSION, CRLF))
	if err then return err end

	headers = __headers(headers)
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
