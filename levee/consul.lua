

function b64dec(data)
	local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	local data = string.gsub(data, '[^'..b..'=]', '')
	return (
		data:gsub('.', function(x)
			if (x == '=') then return '' end
			local r,f='',(b:find(x)-1)
			for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
			return r;
		end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
			if (#x ~= 8) then return '' end
			local c=0
			for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
			return string.char(c)
		end))
end


local Consul_mt = {}
Consul_mt.__index = Consul_mt


function Consul_mt:request(method, path, params, headers, data)
	local conn = self.hub.http:connect(self.port)
	if not conn then return end
	return conn:request(method, "/v1/"..path, params, headers, data):recv()
end


local KV_mt = {}
KV_mt.__index = KV_mt


function KV_mt:get(key)
	local res = self.agent:request("GET", "kv/"..key)
	if res.code ~= 200 then
		res.body:discard()
		return
	end

	local ok, data = res.body:tojson()
	assert(ok)

	for _, item in ipairs(data) do
		item["Value"] = b64dec(item["Value"])
	end

	return res.headers["X-Consul-Index"], data[1]
end


function KV_mt:put(key, value)
	local res = self.agent:request("PUT", "kv/"..key, nil, nil, value)
	res.body:discard()
	return res.code == 200
end


function KV_mt:delete(key)
	local res = self.agent:request("DELETE", "kv/"..key)
	res.body:discard()
	return res.code == 200
end


--
-- Module interface

local M_mt = {}
M_mt.__index = M_mt


function M_mt:__call(port)
	local M = setmetatable({hub = self.hub, port = port or 8500}, Consul_mt)
	M.kv = setmetatable({agent = M}, KV_mt)
	return M
end


return function(hub)
	return setmetatable({hub=hub}, M_mt)
end
