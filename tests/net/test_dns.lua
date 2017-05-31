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

		local addr = "127.0.0.1"
		local port = 1053

		local function server()
			local err, s = h.dgram:bind(port, addr)
			respond(s, "imgx-com-a")
			s:close()
		end
		h:spawn(server)

		local err, resv = h.dns:resolver(port, addr)
		assert(not err)
		local err, records = resv:query("imgx.com", "A")
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

		resv:close()
	end,

	test_txt = function()
		local h = levee.Hub()

		local addr = "127.0.0.1"
		local port = 1053

		local function server()
			local err, s = h.dgram:bind(port, addr)
			respond(s, "imgx-com-txt")
			s:close()
		end
		h:spawn(server)

		local err, resv = h.dns:resolver(port, addr)
		local err, records = resv:query("imgx.com", "TXT")
		assert(#records, 1)
		local expect = record({
			name="imgx.com.",
			type="TXT",
			ttl=983,
			record="\"v=spf1 include:spf.efwd.registrar-servers.com ~all\"",
			section="ANSWER"
		})
		assert.same(records[1], expect)

		resv:close()
	end,

	test_aaaa = function()
		local h = levee.Hub()

		local addr = "127.0.0.1"
		local port = 1053

		local function server()
			local err, s = h.dgram:bind(port, addr)
			respond(s, "lua-org-aaaa")
			s:close()
		end
		h:spawn(server)

		local err, resv = h.dns:resolver(port, addr)
		local err, records = resv:query("lua.org", "AAAA")
		assert(#records, 1)
		local expect = record({
			name="lua.org.",
			type="AAAA",
			ttl=60,
			record="2a01:4f8:201:620f::2001",
			section="ANSWER"
		})
		assert.same(records[1], expect)

		resv:close()
	end,

	test_multi_query = function()
		local h = levee.Hub()

		local addr = "127.0.0.1"
		local port = 1053

		local function server()
			local err, s = h.dgram:bind(port, addr)
			respond(s, "imgx-com-a")
			s:close()
		end
		h:spawn(server)

		local err, resv = h.dns:resolver(port, addr)
		local err, records = resv:query("imgx.com", "A")
		assert(#records, 1)
		local expect = record({
				name="imgx.com.",
				type="A",
				ttl=414,
				record="162.255.119.249",
				section="ANSWER"
		})
		assert.same(records[1], expect)

		local function server()
			local err, s = h.dgram:bind(port, addr)
			respond(s, "imgx-com-txt")
			s:close()
		end
		h:spawn(server)

		err, records = resv:query("imgx.com", "TXT")
		assert(#records, 1)
		local expect = record({
			name="imgx.com.",
			type="TXT",
			ttl=983,
			record="\"v=spf1 include:spf.efwd.registrar-servers.com ~all\"",
			section="ANSWER"
		})
		assert.same(records[1], expect)

		local function server()
			local err, s = h.dgram:bind(port, addr)
			respond(s, "lua-org-aaaa")
			s:close()
		end
		h:spawn(server)

		local err, records = resv:query("lua.org", "AAAA")
		assert(#records, 1)
		local expect = record({
			name="lua.org.",
			type="AAAA",
			ttl=60,
			record="2a01:4f8:201:620f::2001",
			section="ANSWER"
		})
		assert.same(records[1], expect)

		resv:close()
	end,

	test_multi_records = function()
		local h = levee.Hub()

		local addr = "127.0.0.1"
		local port = 1053

		local function server()
			local err, s = h.dgram:bind(port, addr)
			respond(s, "yahoo-com-a")
			s:close()
		end
		h:spawn(server)

		local err, resv = h.dns:resolver(port, addr)
		local err, records = resv:query("yahoo.com", "A")
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

		resv:close()
	end,

	test_type = function()
		local h = levee.Hub()

		local addr = "127.0.0.1"
		local port = 1053

		local function server()
			local err, s = h.dgram:bind(port, addr)
			respond(s, "opendns-org-cname-a")
			s:close()
		end
		h:spawn(server)

		local err, resv = h.dns:resolver(port, addr)
		local err, records = resv:query("opendns.org", "A")
		assert(#records, 1)
		local expect = record({
			name="www.opendns.org.",
			type="A",
			ttl=300,
			record="67.215.92.210",
			section="ANSWER"
		})
		assert.same(records[1], expect)

		resv:close()
	end,

	test_closed = function()
		local h = levee.Hub()
		local err, resv = h.dns:resolver()
		resv:close()

		local err, records = resv:query("imgx.com", "A")
		assert.equal(err, errors.CLOSED)
	end,

	test_ip = function()
		local h = levee.Hub()
		local err, resv = h.dns:resolver()

		local err, records = resv:query("148.251.24.173")
		assert.equal(err, errors.addr.ENONAME)

		local err, records = resv:query("2a01:4f8:201:620f::2001")
		assert.equal(err, errors.addr.ENONAME)

		local err, records = resv:query("2a01:4f8:201:620f::2001", "AAAA")
		assert.equal(err, errors.addr.ENONAME)

		resv:close()
	end,

	test_timeout = function()
		local h = levee.Hub()

		local err, resv = h.dns:resolver(8003, "10.244.245.246")
		local err, records = resv:query("imgx.com", "A", 20)
		assert.equal(err, levee.errors.TIMEOUT)
	end,
}
