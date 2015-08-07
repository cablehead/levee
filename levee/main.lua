local os = require('os')
local command = arg[1]
local handler = nil
local ok = false

if command then
	ok, handler = pcall(require, "levee.cmd." .. command)
end

if not ok then
	print("unkown sub-command")
	os.exit(1)
end

handler({unpack(arg,2)})
