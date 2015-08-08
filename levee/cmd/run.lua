return function(argv)
	local os = require('os')

	local path = argv:next()
	local dir = path:match("^(.*)/[^/]+$")
	local main

	if path:match("%.lua$") or path:match("lua%.test$") then
		main = path
	else
		if not dir then
			io.stderr:write("invalid module path\n")
			os.exit(1)
		end

		if path:sub(-1) == '/' then
			path = path:sub(1, -2)
		end
		main = path .. "/main.lua"
	end

	package.path = dir .. "/?.lua;" .. dir .. "/?/init.lua;" .. package.path

	arg = argv:remain()

	local f, err = loadfile(main)
	if f then
		f()
	else
		io.stderr:write(err)
		io.stderr:write("\n")
	end
end

