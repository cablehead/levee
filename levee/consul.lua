--
-- utilities

local function b64dec(data)
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


local function encode(data)
	if type(data) == "table" then
		local ret = {}
		table.insert(ret, "{")
		for key, value in pairs(data) do
			assert(type(key) == "string")
			table.insert(ret, '"'..key..'"')
			table.insert(ret, ": ")
			table.insert(ret, encode(value))
			table.insert(ret, ", ")
		end
		table.remove(ret)  -- pop trailing ','
		table.insert(ret, "}")
		return table.concat(ret)

	elseif type(data) == "string" then
		return '"'..data..'"'

	else
		print(type(data))
		assert(false)
	end
end


--
-- Consul API

local Consul_mt = {}
Consul_mt.__index = Consul_mt


function Consul_mt:request(method, path, params, headers, data)
	local conn = self.hub.http:connect(self.port)
	if not conn then return end
	return conn:request(method, "/v1/"..path, params, headers, data):recv()
end


--
-- KV namespace

local KV_mt = {}
KV_mt.__index = KV_mt


function KV_mt:get(key)
	local res = self.agent:request("GET", "kv/"..key)
	if res.code ~= 200 then
		res:discard()
		return
	end

	local data = res:json()

	for _, item in ipairs(data) do
		item["Value"] = b64dec(item["Value"])
	end

	return res.headers["X-Consul-Index"], data[1]
end


function KV_mt:put(key, value)
	local res = self.agent:request("PUT", "kv/"..key, nil, nil, value)
	res:discard()
	return res.code == 200
end


function KV_mt:delete(key)
	local res = self.agent:request("DELETE", "kv/"..key)
	res:discard()
	return res.code == 200
end


local Session_mt = {}
Session_mt.__index = Session_mt


function Session_mt:create(options)
	-- options:
	-- 	name
	-- 	node
	-- 	lock_delay
	-- 	behavior
	-- 	ttl

	options = options or {}
	local data = {}

	data.name = options.name
	data.node = options.node

	-- TODO: checks

	if options.lock_delay then
		data.lockdelay = tostring(options.lock_delay).."s"
	end

	data.behavior = options.behavior

	if options.ttl then
		assert(options.ttl >= 10 and options.ttl <= 3600)
		data.ttl = tostring(options.ttl).."s"
	end

	local res = self.agent:request(
		"PUT", "session/create", nil, nil, encode(data))

	assert(res.code == 200)
	return res:json()["ID"]
end


function Session_mt:list()
	local res = self.agent:request("GET", "session/list", nil, nil, nil)
	assert(res.code == 200)
	return res.headers["X-Consul-Index"], res:json()
end


function Session_mt:destroy(session_id)
	local res = self.agent:request(
		"PUT", "session/destroy/"..session_id, nil, nil, nil)
	res:discard()
	return res.code == 200
end


function Session_mt:info(session_id)
	local res = self.agent:request(
		"GET", "session/info/"..session_id, nil, nil, nil)
	assert(res.code == 200)

	local session = res:json()
	if session then session = session[1] end
	return res.headers["X-Consul-Index"], session
end


function Session_mt:renew(session_id)
	local res = self.agent:request(
		"PUT", "session/renew/"..session_id, nil, nil, nil)

	if res.code == 404 then
		res:discard()
		return false
	end

	assert(res.code == 200)
	return res:json()[1]
end


--
-- Module interface

local M_mt = {}
M_mt.__index = M_mt


function M_mt:__call(port)
	local M = setmetatable({hub = self.hub, port = port or 8500}, Consul_mt)
	M.kv = setmetatable({agent = M}, KV_mt)
	M.session = setmetatable({agent = M}, Session_mt)
	return M
end


return function(hub)
	return setmetatable({hub=hub}, M_mt)
end
