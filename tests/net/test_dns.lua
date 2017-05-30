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
		["GOOGLE-A"]={size=766, file="dns-google-a.data"},
		["GOOGLE-B"]={size=766, file="dns-google-b.data"},
		["GOOGLE-A-AAAA"]={size=2298, file="dns-google-a-aaaa.data"},
		["GOOGLE-ADDR"]={size=2298, file="dns-google-addr.data"},
		["YAHOO-A"]={size=766, file="dns-yahoo-a.data"},
	}

	local f = io.open(path.."/"..records[rtype].file, "rb")
	local data = f:read(records[rtype].size)
	f:close()

	return data
end

local function respond(server, rtype)
	local buf = levee.d.Buffer(4096)
	local err, who, n = server:recvfrom(buf:tail())
	buf:bump(n)

	local qid = string.sub(buf:take(), 1,2)
	local data = response(rtype)
	local size = data:len()

	for i=0,(size/TEST_PACK_SIZE)-1 do
		local off = 0
		local packet = string.sub(data, i*TEST_PACK_SIZE+1, (i+1)*TEST_PACK_SIZE)
		packet = qid..packet
		local remain = packet:len()
		while remain > 0 do
				local chunk = string.sub(packet, off+1, off+DNS_PACK_SIZE)
				local err, n = server:sendto(who, chunk)
				if err or n < 0 then n = 0 end
				off = off + n
				remain = remain - n
		end
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
			respond(s, "GOOGLE-A")
			s:close()
		end
		h:spawn(server)

		local err, resv = h.dns:resolver(port, addr)
		assert(not err)
		local err, records = resv:query("google-public-dns-a.google.com", "A")
		assert(not err)
		assert.equal(#records, 1)
		local expect = record({
			name="google-public-dns-a.google.com.",
			type="A",
			ttl=3600,
			record="8.8.8.8",
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
			respond(s, "GOOGLE-A-AAAA")
			s:close()
		end
		h:spawn(server)

		local err, resv = h.dns:resolver(port, addr)
		local err, records = resv:query("google-public-dns-a.google.com", "AAAA")
		local expect = record({
			name="google-public-dns-a.google.com.",
			type="AAAA",
			ttl=86400,
			record="2001:4860:4860::8888",
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
			respond(s, "GOOGLE-A")
			s:close()
		end
		h:spawn(server)

		local err, resv = h.dns:resolver(port, addr)
		local err, records = resv:query("google-public-dns-a.google.com", "A")
		local expect = record({
				name="google-public-dns-a.google.com.",
				type="A",
				ttl=3600,
				record="8.8.8.8",
				section="ANSWER"
		})
		assert.same(records[1], expect)

		local function server()
			local err, s = h.dgram:bind(port, addr)
			respond(s, "GOOGLE-B")
			s:close()
		end
		h:spawn(server)

		err, records = resv:query("google-public-dns-b.google.com", "A")
		local expect = record({
				name="google-public-dns-b.google.com.",
				type="A",
				ttl=3600,
				record="8.8.4.4",
				section="ANSWER"
		})
		assert.same(records[1], expect)

		local function server()
			local err, s = h.dgram:bind(port, addr)
			respond(s, "GOOGLE-A-AAAA")
			s:close()
		end
		h:spawn(server)

		local err, records = resv:query("google-public-dns-a.google.com", "AAAA")
		local expect = record({
			name="google-public-dns-a.google.com.",
			type="AAAA",
			ttl=86400,
			record="2001:4860:4860::8888",
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
			respond(s, "YAHOO-A")
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

	test_closed = function()
		local h = levee.Hub()
		local err, resv = h.dns:resolver()
		resv:close()

		local err, records = resv:query("google-public-dns-a.google.com", "A")
		assert.equal(err, errors.CLOSED)
	end,

	test_address = function()
		local h = levee.Hub()
		local err, resv = h.dns:resolver()

		local err, records = resv:query("8.8.4.4")
		assert.equal(err, errors.addr.ENONAME)

		local err, records = resv:query("2001:4860:4860::8888")
		assert.equal(err, errors.addr.ENONAME)

		local err, records = resv:query("2001:4860:4860::8888", "AAAA")
		assert.equal(err, errors.addr.ENONAME)

		resv:close()
	end,
}
