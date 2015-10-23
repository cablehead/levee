local Bloom = require("levee.d.bloom")


local Set_mt = {}
Set_mt.__index = Set_mt


function Set_mt:__tostring()
	return string.format("levee.Set: %p", self)
end


function Set_mt:__len()
	return self.count
end


function Set_mt:__eq(other)
	if self.keys == other.keys then
		return true
	end
	if self.count ~= other.count then
		return false
	end
	for k,_ in pairs(self.keys) do
		if not other.keys[k] then
			return false
		end
	end
	return true
end


function Set_mt:__add(other)
	return self:copy():union(other)
end


function Set_mt:__div(other)
	return self:copy():intersect(other)
end


function Set_mt:__sub(other)
	return self:copy():diff(other)
end


function Set_mt:is_frozen()
	return not not self.bloom
end


function Set_mt:put(key)
	if self.bloom then
		error("set is frozen", 2)
	end
	if not self.keys[key] then
		self.keys[key] = true
		self.count = self.count + 1
	end
	return self
end


function Set_mt:remove(key)
	if self.bloom then
		error("set is frozen", 2)
	end
	if self.keys[key] then
		self.keys[key] = nil
		self.count = self.count - 1
	end
	return self
end


function Set_mt:has(key)
	if self.bloom and not self.bloom:maybe(key) then
		return false
	end
	return not not self.keys[key]
end


function Set_mt:freeze(fpp)
	if not self.bloom then
		local bloom = Bloom(self.count, fpp)
		for k,_ in pairs(self.keys) do
			bloom:put(k)
		end
		self.bloom = bloom
	end
	return self
end


function Set_mt:union(other)
	if self.bloom then
		error("set is frozen", 2)
	end
	for k,_ in pairs(other.keys) do
		if not self.keys[k] then
			self.keys[k] = true
			self.count = self.count + 1
		end
	end
	return self
end


function Set_mt:intersect(other)
	if self.bloom then
		error("set is frozen", 2)
	end
	for k,_ in pairs(self.keys) do
		if not other.keys[k] then
			self.keys[k] = nil
			self.count = self.count - 1
		end
	end
	return self
end


function Set_mt:diff(other)
	if self.bloom then
		error("set is frozen", 2)
	end
	for k,_ in pairs(other.keys) do
		if self.keys[k] then
			self.keys[k] = nil
			self.count = self.count - 1
		end
	end
	return self
end


function Set_mt:iter()
	local t = self.keys
	local f = pairs(t)
	local k, v
	return function()
		k, v = f(t, k)
		return k
	end
end


function Set_mt:copy()
	local keys = {}
	for k,_ in pairs(self.keys) do
		keys[k] = true
	end
	return setmetatable({ keys=keys, count=self.count }, Set_mt)
end


local function Set(...)
	local keys = {}
	local count = 0
	for i,v in ipairs{...} do
		keys[v] = true
		count = count + 1
	end
	return setmetatable({ keys=keys, count=count }, Set_mt)
end


return Set
