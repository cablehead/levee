local ffi = require('ffi')
local C = ffi.C
local meta = require("levee.meta")
local encoder = require("levee.p.utf8").Utf8
local status = require("levee.p.http.status")


local VERSION = "HTTP/1.1"
local FIELD_SEP = ": "
local CRLF = "\r\n"

local USER_AGENT = ("%s/%s"):format(meta.name, meta.version.string)


--
-- Date response header cache

local http_time = ffi.new("time_t [1]")
local http_date = nil
local http_date_buf = ffi.new("char [32]")
local http_tm = ffi.new("struct tm")

local function httpdate()
	local t = C.time(nil)
	if t ~= http_time[0] then
		http_time[0] = t
		C.gmtime_r(http_time, http_tm)
		local len = C.strftime(
			http_date_buf, 32, "%a, %d %b %Y %H:%M:%S GMT", http_tm)
		http_date = ffi.string(http_date_buf, len)
	end
	return http_date
end


-- TODO make this part of levee.p.uri when it makes sense
local function encode_url(value)
	local buf = ffi.cast("char *", value)
	local e =  encoder()
	local flag = bit.bor(C.SP_UTF8_URI, C.SP_UTF8_SPACE_PLUS)
	local err, n = e:encode(buf, #value, flag)
	if err then return err end
	return nil, ffi.string(e.buf, n)
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
	local err, path = encode_url(path)
	if err then return err end

	buf:push(("%s %s %s%s"):format(method, path, VERSION, CRLF))

	if not headers then headers = {} end
	-- TODO: Host
	if not headers["User-Agent"] then headers["User-Agent"] = USER_AGENT end
	if not headers["Accept"] then headers["Accept"] = "*/*" end

	if data then
		headers["Content-Length"] = tostring(#data)
	end

	for k, v in pairs(headers) do
		if type(v) == "table" then
			for _,item in pairs(v) do
				buf:push(k..FIELD_SEP..item..CRLF)
			end
		else
			buf:push(k..FIELD_SEP..v..CRLF)
		end
	end
	buf:push(CRLF)

	if data then
		buf:push(data)
	end
end


function encode_response(status, headers, body, buf)
	local no_content = status:no_content()
	buf:push(tostring(status))

	if not headers then headers = {} end
	if not headers["Date"] then headers["Date"] = httpdate() end

	if no_content or not body then
		headers["Content-Length"] = nil
	elseif type(body) == "string" then
		headers["Content-Length"] = tostring(#body)
	else
		headers["Content-Length"] = tostring(tonumber(body))
	end

	for k, v in pairs(headers) do
		if type(v) == "table" then
			for _,item in pairs(v) do
				buf:push(k..FIELD_SEP..item..CRLF)
			end
		else
			buf:push(k..FIELD_SEP..v..CRLF)
		end
	end
	buf:push(CRLF)

	if not no_content and type(body) == "string" then
		buf:push(body)
	end

	return nil, buf
end


return {
	Status=status,
	encode_request=encode_request,
	encode_response=encode_response
}
