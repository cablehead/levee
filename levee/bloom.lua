local ffi = require("ffi")
local rand = require('levee.rand')
local C = ffi.C




local Bloom_mt = {}
Bloom_mt.__index = Bloom_mt

local BloomScale_mt = {}
BloomScale_mt.__index = BloomScale_mt

local bloom_seed = rand.integer()




function Bloom_mt:__tostring()
	return string.format("levee.Bloom: %p", self)
end


function Bloom_mt:is_capable(hint, fpp)
	return C.sp_bloom_is_capable(self, hint, fpp or self.fpp)
end


-- TODO: support more types
function Bloom_mt:hash(val, len)
	return C.sp_bloom_hash(self, val, len or #val)
end


function Bloom_mt:put(val, len)
	return self:put_hash(self:hash(val, len))
end


function Bloom_mt:put_hash(hash)
	C.sp_bloom_put_hash(self, hash)
	return self
end


function Bloom_mt:maybe(val, len)
	return self:maybe_hash(self:hash(val, len))
end


function Bloom_mt:maybe_hash(hash)
	return C.sp_bloom_maybe_hash(self, hash)
end


function Bloom_mt:clear()
	C.sp_bloom_clear(self)
end


function Bloom_mt:copy()
	return ffi.gc(C.sp_bloom_copy(self), C.sp_bloom_destroy)
end


function Bloom_mt:scale()
	return setmetatable({self}, BloomScale_mt)
end


ffi.metatype("SpBloom", Bloom_mt)


local function Bloom(hint, fpp, seed)
	local self = C.sp_bloom_create(hint or 0, fpp or 0.01, seed or bloom_seed)
	return ffi.gc(self, C.sp_bloom_destroy)
end




function BloomScale_mt:__tostring()
	return string.format("levee.Bloom: %p", self)
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


function BloomScale_mt:scale()
	return self:copy()
end


return Bloom
