local M = {}


local function _assets(path)
	local t = {}
	table.insert(t, '{')
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
	return table.concat(t)
end


function M.assets(path)
	return loadstring("return ".._assets(path))
end


function M.templates(path)
	return loadstring(([[
		local _ = require("levee")._
		local assets = %s
		for k, v in pairs(assets) do
			assets[k] = _.template(v)
		end
		return assets
	]]):format(_assets(path)))
end


return M
