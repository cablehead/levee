local ev = require("ev")

local conn = ev.tcp.connect(8000)

for _, str in ipairs{"hello", "goodbye"} do
	conn:send(str)
	print(conn:recv())
end

conn:close()

