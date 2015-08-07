return function(args)
	local os = require('os')

	local path = args[1]
	if path:sub(-1) == '/' then
		path = path:sub(1, -2)
	end

	local dir, name = path:match("(.*)/(.*)")
	local main = path .. "/main.lua"
	package.path = dir .. "/?.lua;" .. dir .. "/?/init.lua;" .. package.path

	local newarg = {unpack(args, 2)}
	newarg[0] = arg[0]
	arg = newarg

	local f, err = loadfile(main)
	if f then
		f()
	else
		io.stderr:write(err)
		io.stderr:write("\n")
	end
end

