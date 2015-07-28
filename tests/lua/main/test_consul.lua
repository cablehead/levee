local levee = require("levee")


return {
	test_kv = function()
		local h = levee.Hub()
		local c = h.consul()

		-- clean up old runs
		assert.equal(c.kv:delete("foo"), true)
		--

		assert.equal(c.kv:get("foo"), nil)
		assert.equal(c.kv:put("foo", "bar"), true)

		local index, data = c.kv:get("foo")
		assert.equal(data["Value"], "bar")

		assert.equal(c.kv:delete("foo"), true)
		assert.equal(c.kv:get("foo"), nil)
	end,

	test_session = function()
		local h = levee.Hub()
		local c = h.consul()

		-- clean up old runs
		local index, sessions = c.session:list()
		for _, session in pairs(sessions) do
			c.session:destroy(session["ID"])
		end
		--

		local session_id = c.session:create({behavior="delete", ttl=10})

		local index, sessions = c.session:list()
		assert.equal(#sessions, 1)
		assert.equal(sessions[1]["ID"], session_id)

		local index, session = c.session:info("foo")
		assert.equal(session, nil)
		local index, session = c.session:info(session_id)
		assert.equal(session["ID"], session_id)

	end,
}
