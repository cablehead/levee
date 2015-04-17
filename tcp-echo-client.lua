local ev = require("ev")


local h = ev.Hub:new()

local p = h:pipe()

h:spawn(function()
	print("in spawned")
end)

p:recv()


print("done")


if false then
	local conn = ev.tcp.connect(8000)

	for _, str in ipairs{"hello", "goodbye"} do
		conn:send(str)
		print(conn:recv())
	end

	conn:close()
end
