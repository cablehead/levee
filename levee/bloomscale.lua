local ffi = require("ffi")
local C = ffi.C
local Bloom = require("levee.bloom")


local BloomScale_mt = {}
BloomScale_mt.__index = BloomScale_mt


function BloomScale_mt:__tostring()
	return string.format("levee.BloomScale: %p", self)
end


function BloomScale_mt:is_capable(hint, fpp)
	return true
end


function BloomScale_mt:hash(val, len)
	return self[1]:hash(val, len)
end


function BloomScale_mt:put(val, len)
	return self:put_hash(self:hash(val, len))
end


function BloomScale_mt:put_hash(hash)
	if not C.sp_bloom_can_hold(self[1], 1) then
		local cnt = self[1].count * (1 + self[1].fpp)
		local new = Bloom(cnt * 8, self[1].fpp, self[1].seed)
		table.insert(self, 1, new)
	end
	C.sp_bloom_put_hash(self[1], hash)
	return self
end


function BloomScale_mt:maybe(val, len)
	return self:maybe_hash(self:hash(val, len))
end


function BloomScale_mt:maybe_hash(hash)
	for i=1,#self do
		if self[i]:maybe_hash(hash) then
			return true
		end
	end
	return false
end


function BloomScale_mt:clear()
	for i=#self,2,-1 do
		table.remove(self)
	end
	C.sp_bloom_clear(self[1])
end


function BloomScale_mt:copy()
	local copy = {}
	for i=1,#self do
		copy[i] = self[i]:copy()
	end
	return setmetatable(copy, BloomScale_mt)
end


local function BloomScale(hint, fpp, seed)
	return setmetatable({Bloom(hint, fpp, seed)}, BloomScale_mt)
end


return BloomScale
