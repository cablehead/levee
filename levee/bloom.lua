local ffi = require("ffi")
local rand = require('levee.rand')
local C = ffi.C

local Bloom_mt = {}
Bloom_mt.__index = Bloom_mt


local bloom_seed = rand.integer()


function Bloom_mt:__tostring()
	return string.format("levee.Bloom: %p", self)
end


function Bloom_mt:is_capable(hint, fpp)
	return C.sp_bloom_is_capable(self, hint, fpp or 0.01)
end


function Bloom_mt:put(val, len)
	C.sp_bloom_put(self, val, len or #val)
	return self
end


function Bloom_mt:push_hash(hash)
	C.sp_bloom_put_hash(self, hash)
	return self
end


function Bloom_mt:maybe(val, len)
	return C.sp_bloom_maybe(self, val, len or #val)
end


function Bloom_mt:maybe_hash(hash)
	return C.sp_bloom_maybe_hash(self, hash)
end


function Bloom_mt:clear()
	C.sp_bloom_clear(self)
end


ffi.metatype("SpBloom", Bloom_mt)


local function Bloom(hint, fpp, seed)
	local self = C.sp_bloom_create(hint or 0, fpp or 0.01, seed or bloom_seed)
	return ffi.gc(self, C.sp_bloom_destroy)
end


return Bloom
