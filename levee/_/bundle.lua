return function(path)
	local t = {}
	table.insert(t, 'return {')
	local cmd = "find -L '"..path.."' -type f"
	for file in io.popen(cmd):lines() do
		table.insert(t, ('\n\t["%s"] = "'):format(file:sub(#path+1)))
		local f = io.open(file, "rb")
		while true do
			local b = f:read(1)
			if not b then break end
			table.insert(t, "\\")
			table.insert(t, "x")
			table.insert(t, ("%02X"):format(string.byte(b)))
		end
		table.insert(t, '",')
		f:close()
	end
	table.insert(t, " }")
	return loadstring(table.concat(t))
end
