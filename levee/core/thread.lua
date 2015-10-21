local levee = require("levee")


local Thread_mt = {}
Thread_mt.__index = Thread_mt


function Thread_mt:call(f, ...)
	local state = levee.State()

	-- bootstrap
	assert(state:load_function(
		function(sender, f, ...)
			local ok, got = pcall(loadstring(f), ...)

			if not ok then
				-- TODO: we should work an optional error message into Pipe close
				print("ERROR:", got)
			else
				-- TODO: close
				sender:send(got)
			end
		end))

	local recver = self.hub:channel():bind()
	state:push(recver:create_sender())

	state:push(string.dump(f))

	local args = {...}
	for i = 1, #args do
		state:push(args[i])
	end
	state:run(2 + #args, true)

	return recver
end


function Thread_mt:spawn(f)
	local state = levee.State()

	-- bootstrap
	assert(state:load_function(
		function(sender, f)
			local levee = require("levee")
			local h = levee.Hub()
			h.parent = levee.message.Pair(sender, sender:connect(h:channel()))

			local ok, got = pcall(loadstring(f), h)

			if not ok then
				-- TODO: we should work an optional error message into Pipe close
				print("ERROR:", got)
			else
				-- TODO: close
			end
		end))

		local recver = self.hub:channel():bind()
		state:push(recver:create_sender())

		state:push(string.dump(f))
		state:run(2, true)

		return levee.message.Pair(recver:recv(), recver)
end


return function(hub)
	return setmetatable({hub = hub}, Thread_mt)
end
