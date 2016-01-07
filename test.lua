local levee = require("levee")
local _ = levee._
local hub = levee.Hub()

local err, serve = hub.http:listen(8080, { max_value = 4096 })
for conn in serve do
	hub:spawn(function()
		for req in conn do
			print(_.repr(req.headers))
			req.response:send({levee.HTTPStatus(200), {}, "OK"})
		end
	end)
end
