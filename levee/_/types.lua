local _ = {}


-- http://ericjmritz.name/2014/02/26/lua-is_array/
function _.is_array(t)
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end


function _.repr(val, depth, seen)
	depth = depth or 0
	seen = seen or {}

	if type(val) == "table" then
		if seen[val] then return tostring(val) end
		seen[val] = 1

		if _.is_array(val) then
			-- encode empty tables as dicts
			if #val == 0 then return "{}" end

			local s = "{"
			local indent = string.rep("\t", depth+1)
			local first = true
			for i, v in ipairs(val) do
				if first then
					first = false
					s = s .. "\n"
				else
					s = s .. ",\n"
				end
				s = s .. indent .. _.repr(v, depth + 1, seen)
			end
			s = s .. " }"
			return s

		else
			local s = "{"
			local indent = string.rep("\t", depth+1)
			local first = true
			for k, v in pairs(val) do
				if first then
					first = false
					s = s .. "\n"
				else
					s = s .. ",\n"
				end
				s = s .. indent .. tostring(k) .. " = " .. _.repr(v, depth + 1, seen)
			end
			return s .. " }"
		end

	elseif type(val) == "string" then
		return '"' .. val:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'

	else
		return tostring(val)
	end
end


return _
