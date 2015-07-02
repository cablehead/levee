return {
	test_core = function()
		local levee = require("levee")

		--
		-- quick Pair class, should go in levee.message
		local Pair_mt = {}
		Pair_mt.__index = Pair_mt

		function Pair_mt:send()
			return self.sender:send()
		end

		function Pair_mt:recv()
			return self.recver:recv()
		end

		local function Pair(sender, recver)
			return setmetatable({sender=sender, recver=recver}, Pair_mt)
		end
		--

		local function bootstrap(sender, f)
			local h = levee.Hub()

			local chan = h:channel()
			local recver = chan:bind()
			sender:send(recver:create_sender())

			h.parent = Pair(sender, recver)

			f(h)
		end

		local function spawn(h, f)
			local chan = h:channel()
			local recver = chan:bind()
			local sender = recver:create_sender()

			local s = levee.State()

			if s:load_function(bootstrap) then
				s:push(sender)
				s:push(f)
				s:run(2, true)
			end

			print()
			print()
			print("this will fail as we can't send 'senders' yet")
			print()
			local other = recver:recv()
			print("Yuzzah! working")
			return Pair(other, recver)
		end

		local function produce(h)
			h.parent:send(1)
		end

		-- main
		h = levee.Hub()
		local child = spawn(h, produce)
		print(child:recv())
	end,
}
