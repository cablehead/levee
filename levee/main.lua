local os = require('os')

local Argv = require('levee.argv')
local cmd = require('levee.cmd')


local function usage()
	local ret = {
		"usage: levee <command> ...\n\n",
		"Available commands are:\n", }

	for k, v in pairs(cmd) do
		table.insert(ret, "\t"..k)
		table.insert(ret, "\n")
	end

	table.remove(ret)  -- pop trailing newline
	return table.concat(ret)
end


-- main

local command = arg[1]

if not cmd[command] then
	if not command then
		print(usage())
	else
		print("unknown command: " .. command)
	end
	os.exit(1)
end

local ok, result = pcall(cmd[command], Argv(arg,2))
if not ok then
	print(result)
	os.exit(1)
end
