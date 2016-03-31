local levee = require("levee")


return {
	skipif = function()
		local h = levee.Hub()
		local err, conn = h.tcp:connect(8500)
		if not conn then return true end
		conn:close()
		return false
	end,

	test_agent_self = function()
		local h = levee.Hub()
		local c = h:consul()
		local err, data = c.agent:self()
		assert(data.Member)
	end,

	test_kv_core = function()
		local h = levee.Hub()
		local c = h:consul()

		-- clean up old runs
		c.kv:delete("foo/", {recurse=true})
		local err, index, sessions = c.session:list()
		for _, session in pairs(sessions) do
			c.session:destroy(session["ID"])
		end
		--

		local err, session_id = c.session:create({behavior="delete", lock_delay=0})

		local sender, recver = h:pipe()
		h:spawn(function()
			local err, index, data
			while true do
				err, index, data = c.kv:get(
					"foo/", {index=index, recurse=true, keys=true})
				sender:send(data)
			end
		end)

		assert.same({recver:recv()}, {nil, {}})

		assert.same({c.kv:put("foo/1", "1")}, {nil, true})
		local err, index, data = c.kv:get("foo/1")
		assert.equal(data["Value"], "1")
		assert.same({recver:recv()}, {nil, {"foo/1"}})

		assert.same({c.kv:put("foo/2", "2", {acquire=session_id})}, {nil, true})
		assert.same({recver:recv()}, {nil, {"foo/1", "foo/2"}})

		local err, other_id = c.session:create()
		assert.same({c.kv:put("foo/2", "2", {acquire=other_id})}, {nil, false})
		assert.same({c.kv:put("foo/2", "2", {release=other_id})}, {nil, false})
		assert.same({c.session:destroy(other_id)}, {nil, true})

		assert.same({c.kv:put("foo/3", "3", {acquire=session_id})}, {nil, true})
		assert.same({recver:recv()}, {nil, {"foo/1", "foo/2", "foo/3"}})

		assert.same({c.kv:put("foo/4", "4")}, {nil, true})
		assert.same({recver:recv()}, {nil, {"foo/1", "foo/2", "foo/3", "foo/4"}})

		assert.same({c.kv:delete("foo/1")}, {nil, true})
		assert.same({recver:recv()}, {nil, {"foo/2", "foo/3", "foo/4"}})

		assert.same({c.kv:put("foo/2", "2", {release=session_id})}, {nil, true})
		assert.same({recver:recv()}, {nil, {"foo/2", "foo/3", "foo/4"}})

		c.session:destroy(session_id)
		assert.same({recver:recv()}, {nil, {"foo/2", "foo/4"}})

		assert.same({c.kv:delete("foo/", {recurse=true})}, {nil, true})
		assert.same({recver:recv()}, {nil, {}})
	end,

	test_kv_put_nil = function()
		local h = levee.Hub()
		local c = h:consul()
		c.kv:put("foo")
		local err, index, data = c.kv:get("foo")
		assert.equal(data.Value, nil)
		c.kv:delete("foo")
	end,

	test_kv_put_cas = function()
		local h = levee.Hub()
		local c = h:consul()

		-- clean up old runs
		c.kv:delete("foo")
		--

		c.kv:put("foo", "1", {cas=0})
		local err, index, data = c.kv:get("foo")
		assert.equal(data.Value, "1")

		assert.same({c.kv:put("foo", "2", {cas=0})}, {nil, false})
		local err, index, data = c.kv:get("foo")
		assert.equal(data.Value, "1")

		c.kv:delete("foo")
	end,

	test_session = function()
		local h = levee.Hub()
		local c = h:consul()

		-- clean up old runs
		local err, index, sessions = c.session:list()
		for _, session in pairs(sessions) do
			c.session:destroy(session["ID"])
		end
		--

		local err, session_id = c.session:create({behavior="delete", ttl=10})

		local err, index, sessions = c.session:list()
		assert.equal(#sessions, 1)
		assert.equal(sessions[1]["ID"], session_id)

		local err, index, session = c.session:info("foo")
		assert.equal(session, nil)
		local err, index, session = c.session:info(session_id)
		assert.equal(session["ID"], session_id)

		local err, session = c.session:renew("foo")
		assert(err)
		local err, session = c.session:renew(session_id)
		assert.equal(session["ID"], session_id)

		c.session:destroy(session_id)
		local err, index, sessions = c.session:list()
		assert.equal(#sessions, 0)
	end,

	test_service = function()
		local h = levee.Hub()
		local c = h:consul()

		-- clean up old runs
		c.agent.service:deregister("foo")
		--

		assert.same({c.agent.check:pass("service:foo")}, {nil, false})

		local sender, recver = h:pipe()
		h:spawn(function()
			local err, index, services
			while true do
				err, index, services = c.health:service("foo", {index=index})
				sender:send(services)
			end
		end)
		local err, services = recver:recv()
		assert.equal(#services, 0)

		local err, rc = c.agent.service:register("foo", {check={ttl="5s"}})
		assert.equal(rc, true)

		local err, services = c.agent:services()
		assert(services["foo"])
		local err, services = recver:recv()
		assert.equal(#services, 1)

		-- mark ttl as passed
		assert.same({c.agent.check:pass("service:foo")}, {nil, true})
		local err, services = c.agent:services()
		local err, services = recver:recv()
		assert.equal(#services, 1)

		assert.same({c.agent.service:deregister("foo")}, {nil, true})
		local err, services = c.agent:services()
		assert.equal(services["foo"], nil)

		local err, index, services = c.health:service("foo")
		local err, services = recver:recv()
		assert.equal(#services, 0)
	end,

	test_election = function()
		local h = levee.Hub()
		local c = h:consul()

		-- clean up old runs
		c.kv:delete("foo/", {recurse=true})

		local err, index, sessions = c.session:list()
		for _, session in pairs(sessions) do
			c.session:destroy(session["ID"])
		end
		--

		local err, s1 = c.session:create({behavior="delete", lock_delay=0})
		local err, r1 = c:election("foo/", s1, 2)
		assert.same({r1:recv()}, {nil, true})

		local err, s2 = c.session:create({behavior="delete", lock_delay=0})
		local err, r2 = c:election("foo/", s2, 2)
		assert.same({r2:recv()}, {nil, true})


		local err, s3 = c.session:create({behavior="delete", lock_delay=0})
		local err, r3 = c:election("foo/", s3, 2)

		local err, s4 = c.session:create({behavior="delete", lock_delay=0})
		local err, r4 = c:election("foo/", s4, 2)

		assert.equal(r1:recv(10), levee.errors.TIMEOUT)
		assert.equal(r2:recv(10), levee.errors.TIMEOUT)
		assert.equal(r3:recv(10), levee.errors.TIMEOUT)
		assert.equal(r4:recv(10), levee.errors.TIMEOUT)

		c.session:destroy(s2)
		assert.same({r3:recv(10)}, {nil, true})
		assert.equal(r2:recv(), levee.errors.CLOSED)
		assert.equal(r4:recv(10), levee.errors.TIMEOUT)

		c.session:destroy(s1)
		assert.equal(r1:recv(), levee.errors.CLOSED)
		assert.same({r4:recv(10)}, {nil, true})

		c.session:destroy(s4)
		assert.equal(r4:recv(), levee.errors.CLOSED)
		assert.equal(r3:recv(10), levee.errors.TIMEOUT)

		c.session:destroy(s3)
		assert.equal(r3:recv(10), levee.errors.CLOSED)
	end,
}
