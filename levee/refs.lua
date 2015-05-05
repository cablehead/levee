-- A place to keep references to things. This is almost certainly a bad idea.


local refs = {}
-- setmetatable(refs, {__mode = 'v'})


return {
	new = function(t)
		table.insert(refs, t)
		return #refs
	end,

	get = function(i)
		return refs[i]
	end,

	clear = function(i)
		local data = refs[i]
		refs[i] = nil
		return data
	end,
}
