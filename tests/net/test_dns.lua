local levee = require("levee")
local _ = levee._

local errors = require("levee.errors")


return {
	test_core = function()
		local h = levee.Hub()
		local err, resv = h.dns:resolver()
		assert(not err)

		local err, records = resv:query("google-public-dns-a.google.com", "A")
		assert(not err)
		assert.equal(#records, 1)
		local expect = {
			name="google-public-dns-a.google.com.",
			type="A",
			ttl=3600,
			record="8.8.8.8",
			section="ANSWER"
		}
		assert.same(records[1], expect)

		resv:close()
	end,

	test_closed = function()
		local h = levee.Hub()
		local err, resv = h.dns:resolver()
		resv:close()

		local err, records = resv:query("google-public-dns-a.google.com", "A")
		assert.equal(err, errors.CLOSED)
	end,

	test_aaaa = function()
		local h = levee.Hub()
		local err, resv = h.dns:resolver()

		local err, records = resv:query("google-public-dns-a.google.com", "AAAA")
		local expect = {
			name="google-public-dns-a.google.com.",
			type="AAAA",
			ttl=86400,
			record="2001:4860:4860::8888",
			section="ANSWER"
		}
		assert.same(records[1], expect)

		resv:close()
	end,

	test_multi_query = function()
		local h = levee.Hub()
		local err, resv = h.dns:resolver()

		local err, records = resv:query("google-public-dns-a.google.com", "A")
		local expect = {
				name="google-public-dns-a.google.com.",
				type="A",
				ttl=3600,
				record="8.8.8.8",
				section="ANSWER"
		}
		assert.same(records[1], expect)

		err, records = resv:query("google-public-dns-b.google.com", "A")
		local expect = {
				name="google-public-dns-b.google.com.",
				type="A",
				ttl=3600,
				record="8.8.4.4",
				section="ANSWER"
		}
		assert.same(records[1], expect)

		local err, records = resv:query("google-public-dns-a.google.com", "AAAA")
		local expect = {
			name="google-public-dns-a.google.com.",
			type="AAAA",
			ttl=86400,
			record="2001:4860:4860::8888",
			section="ANSWER"
		}
		assert.same(records[1], expect)

		resv:close()
	end,

	test_multi_records = function()
		local h = levee.Hub()
		local err, resv = h.dns:resolver()
		assert(not err)

		local err, records = resv:query("yahoo.com", "A")
		assert(not err)
		assert.equal(#records, 3)
		table.sort(records)
		local expect = {
			{
				name="yahoo.com.",
				type="A",
				ttl=3600,
				record="206.190.36.45",
				section="ANSWER"
			},
			{
				name="yahoo.com.",
				type="A",
				ttl=3600,
				record="98.139.183.24",
				section="ANSWER"
			},
			{
				name="yahoo.com.",
				type="A",
				ttl=3600,
				record="98.138.253.109",
				section="ANSWER"
			},
		}
		assert.same(records, expect)

		resv:close()
	end,

	test_address = function()
		local h = levee.Hub()
		local err, resv = h.dns:resolver()
		assert(not err)

		local err, records = resv:query("8.8.4.4.", "A")
		assert(not err)
		assert.equal(#records, 1)
		local expect = {
			name="8.8.4.4.",
			type="A",
			ttl=3600,
			record="8.8.4.4",
			section="ANSWER"
		}
		assert.same(records[1], expect)

		resv:close()
	end,
}
