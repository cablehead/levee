local levee = require("levee")


local Thread_mt = {}
Thread_mt.__index = Thread_mt


function Thread_mt:call(f, ...)
	local state = levee.State()

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
end


return function(hub)
	return setmetatable({hub = hub}, Thread_mt)
end
