local levee = require("levee")
local _ = levee._

local errors = require("levee.errors")

local filename = debug.getinfo(1, 'S').source:sub(2)
local path = _.path.dirname(filename)


local DNS_PACK_SIZE = 768
-- Make room for the leading 16-bit QID
local TEST_PACK_SIZE = 766


local function response(rtype)
	local records = {
		["imgx-com-a"]="dns-imgx-com-a.data",
		["imgx-com-aaaa"]="dns-imgx-com-aaaa.data",
		["imgx-com-txt"]="dns-imgx-com-txt.data",
		["lua-org-aaaa"]="dns-lua-org-aaaa.data",
		["opendns-org-cname-a"]="dns-opendns-org-cname-a.data",
		["yahoo-com-a"]="dns-yahoo-com-a.data",
	}

	local f = io.open(path.."/"..records[rtype], "rb")
	local data = f:read(TEST_PACK_SIZE)
	f:close()

	return data
end

local function respond(server, rtype)
	local buf = levee.d.Buffer(4096)
	local err, who, n = server:recvfrom(buf:tail())
	buf:bump(n)

	local qid = string.sub(buf:take(), 1, 2)
	local data = response(rtype)
	local packet = qid..data

	local off = 0
	local remain = packet:len()
	while remain > 0 do
		local chunk = string.sub(packet, off+1, off+DNS_PACK_SIZE)
		local err, n = server:sendto(who, chunk)
		if err or n < 0 then n = 0 end
		off = off + n
		remain = remain - n
	end
end


local record_mt = {}
record_mt.__index = record_mt


function record_mt:__eq(b)
	if self.name ~= b.name then return false end
	if self.type ~= b.type then return false end
	if self.record ~= b.record then return false end
	if self.ttl ~= b.ttl then return false end
	if self.section ~= b.section then return false end

	return true
end

local function record(r)
	return setmetatable(r, record_mt)
end


return {
	test_core = function()
		local h = levee.Hub()

		local host = "127.0.0.1"
		local port = 1053

		local function server()
			local err, s = h.dgram:bind(port, host)
			respond(s, "imgx-com-a")
			s:close()
		end
		h:spawn(server)

		local opts = {port=port, host=host}
		local err, records = h.dns:resolve("imgx.com", "A", opts)
		assert(not err)
		assert.equal(#records, 1)
		local expect = record({
			name="imgx.com.",
			type="A",
			ttl=414,
			record="162.255.119.249",
			section="ANSWER"
		})
		assert.same(records[1], expect)
	end,

	test_txt = function()
		local h = levee.Hub()

		local host = "127.0.0.1"
		local port = 1053

		local function server()
			local err, s = h.dgram:bind(port, host)
			respond(s, "imgx-com-txt")
			s:close()
		end
		h:spawn(server)

		local opts = {port=port, host=host}
		local err, records = h.dns:resolve("imgx.com", "TXT", opts)
		assert(#records, 1)
		local expect = record({
			name="imgx.com.",
			type="TXT",
			ttl=983,
			record="\"v=spf1 include:spf.efwd.registrar-servers.com ~all\"",
			section="ANSWER"
		})
		assert.same(records[1], expect)
	end,

	test_aaaa = function()
		local h = levee.Hub()

		local host = "127.0.0.1"
		local port = 1053

		local function server()
			local err, s = h.dgram:bind(port, host)
			respond(s, "lua-org-aaaa")
			s:close()
		end
		h:spawn(server)

		local opts = {port=port, host=host}
		local err, records = h.dns:resolve("lua.org", "AAAA", opts)
		assert(#records, 1)
		local expect = record({
			name="lua.org.",
			type="AAAA",
			ttl=60,
			record="2a01:4f8:201:620f::2001",
			section="ANSWER"
		})
		assert.same(records[1], expect)
	end,

	test_multi_records = function()
		local h = levee.Hub()

		local host = "127.0.0.1"
		local port = 1053

		local function server()
			local err, s = h.dgram:bind(port, host)
			respond(s, "yahoo-com-a")
			s:close()
		end
		h:spawn(server)

		local opts = {port=port, host=host}
		local err, records = h.dns:resolve("yahoo.com", "A", opts)
		assert.equal(#records, 3)
		local expect = {
			record({
				name="yahoo.com.",
				type="A",
				ttl=3600,
				record="98.138.253.109",
				section="ANSWER"
			}),
			record({
				name="yahoo.com.",
				type="A",
				ttl=3600,
				record="98.139.183.24",
				section="ANSWER"
			}),
			record({
				name="yahoo.com.",
				type="A",
				ttl=3600,
				record="206.190.36.45",
				section="ANSWER"
			}),
		}
		assert.same(records, expect)
	end,

	test_type = function()
		local h = levee.Hub()

		local host = "127.0.0.1"
		local port = 1053

		local function server()
			local err, s = h.dgram:bind(port, host)
			respond(s, "opendns-org-cname-a")
			s:close()
		end
		h:spawn(server)

		local opts = {port=port, host=host}
		local err, records = h.dns:resolve("opendns.org", "A", opts)
		assert(#records, 1)
		local expect = record({
			name="www.opendns.org.",
			type="A",
			ttl=300,
			record="67.215.92.210",
			section="ANSWER"
		})
		assert.same(records[1], expect)
	end,

	test_ip = function()
		local h = levee.Hub()

		local err = h.dns:resolve("148.251.24.173")
		assert.equal(err, errors.addr.ENONAME)

		local err = h.dns:resolve("2a01:4f8:201:620f::2001")
		assert.equal(err, errors.addr.ENONAME)

		local err = h.dns:resolve("2a01:4f8:201:620f::2001", "AAAA")
		assert.equal(err, errors.addr.ENONAME)
	end,

	test_timeout = function()
		local h = levee.Hub()

		local opts = {port=8003, host="10.244.245.246", timeout=20}
		local err, records = h.dns:resolve("imgx.com", "A", opts)
		assert.equal(err, levee.errors.TIMEOUT)
	end,

	test_failover = function()
		 local h = levee.Hub()

		 local host = "127.0.0.1"
		 local port = 1153

		 local function server()
				local err, s = h.dgram:bind(port, host)

				local buf = levee.d.Buffer(4096)

				-- first resolver
				local err, who, n = s:recvfrom(buf:tail())
				local err, who, n = s:recvfrom(buf:tail())

				-- second resolver
				local err, who, n = s:recvfrom(buf:tail())
				respond(s, "imgx-com-a")

				s:close()
		end
		h:spawn(server)

		local tmp = _.path.Path:tmpdir()
		defer(function() tmp:remove(true) end)
		tmp = tmp("resolvconf")
		-- port and host will replace each of the nameservers
		tmp:write("nameserver 0.0.0.1\nnameserver 0.0.0.2")
		local path = tostring(tmp)

		local opts = {port=port, host=host, timeout=20, resconf=path}
		local err = h.dns:resolve("imgx.com", "A", opts)
		assert(err.is_levee_TIMEOUT)

		local err, records = h.dns:resolve("imgx.com", "A", opts)
		assert(not err)
		assert.equal(#records, 1)
	end,

	test_rcode = function()
		local h = levee.Hub()

		local host = "127.0.0.1"
		local port = 1053

		local function server()
			local err, s = h.dgram:bind(port, host)
			respond(s, "imgx-com-aaaa")
			s:close()
		end
		h:spawn(server)

		local opts = {port=port, host=host}
		local err, records = h.dns:resolve("imgx.com", "AAAA", opts)
		assert(err.is_dns_NOTIMP)
	end
}
