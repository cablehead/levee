local levee = require("levee")

levee.run(function(h)
	function echo(conn)
		for message in conn do
			print("Echo:", message)
		end
	end

	local serve = h.tcp:listen(8000)

	while true do
		local conn = serve:recv()
		h:spawn(echo, conn)
	end
end)


if false then
	local levee = require("levee")

	levee.run(function(h)

		local serve = h.tcp:listen(8000)

		while true do
			local conn = serve:recv()
			print("ACCEPTED", conn)

			h:spawn(function()
				for message in conn do
					print("ECHO", message)
				end
				print("ECHO DONE")
			end)
		end

	end)
end



print("done")


-----


if false then
	local conn = levee.tcp.connect(8000)

	for _, str in ipairs{"hello", "goodbye"} do
		conn:send(str)
		print(conn:recv())
	end

	conn:close()
end
