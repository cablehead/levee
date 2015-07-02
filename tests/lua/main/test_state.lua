return {
	test_core = function()
		local levee = require("levee")

		local function spawn(h, f)
			local recver = h:channel():bind()

			local state = levee.State()

			if state:load_function(f) then
				state:push(recver:create_sender())
				state:run(1, true)
			end

			return levee.message.Pair(recver:recv(), recver)
		end


		local function produce(sender)
			local function run()
				local levee = require("levee")

				local h = levee.Hub()
				local recver = sender:connect(h:channel())

				h.parent = levee.message.Pair(sender, recver)
				assert(h.parent:recv() == 123)
				h.parent:send(321)
			end

			local ok, err = pcall(run)
			if not ok then
				print("ERROR:", err)
			end
		end

		-- main

		local h = levee.Hub()

		local child = spawn(h, produce)

		child:send(123)

		assert.equal(child:recv(), 321)

	end,
}
