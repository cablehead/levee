return function(argv)
	local os = require('os')

	local path = argv:string()
	if path:sub(-1) == '/' then
		path = path:sub(1, -2)
	end

	local dir, name = path:match("(.*)/(.*)")
	local main = path .. "/main.lua"
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

