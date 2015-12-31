local ffi = require("ffi")
local C = ffi.C


local errors = require("levee.errors")


local HashRingNode_mt = {}
HashRingNode_mt.__index = HashRingNode_mt


function HashRingNode_mt:__tostring()
	return string.format("levee.HashRingNode: name=%s, avail=%d", self:key(), self.avail)
end


function HashRingNode_mt:key()
	return ffi.string(self._key, self.keylen)
end


function HashRingNode_mt:available()
	return self.avail > 0
end


function HashRingNode_mt:restore()
	C.sp_ring_restore(self.ring, self)
end


ffi.metatype("SpRingNode", HashRingNode_mt)



local HashRingReplica_mt = {}
HashRingReplica_mt.__index = HashRingReplica_mt


function HashRingReplica_mt:__tostring()
	return string.format("levee.HashRingReplica: %p", self)
end


function HashRingReplica_mt:next()
	return C.sp_ring_next(self.node.ring, self)
end


function HashRingReplica_mt:available()
	return self.node.avail > 0
end


function HashRingReplica_mt:reserve()
	local node = C.sp_ring_reserve(self.node.ring, self)
	if node == nil then return end
	return node
end


function HashRingReplica_mt:iter()
	local rep = self
	local done = false
	return function()
		if done then return end
		local n = rep.node
		rep = rep:next()
		if rep == self then done = true end
		return n
	end
end


ffi.metatype("SpRingReplica", HashRingReplica_mt)



local HashRing_mt = {}
HashRing_mt.__index = HashRing_mt


function HashRing_mt:__new(fn)
	local self = ffi.new(self)
	C.sp_ring_init(self, fn or C.sp_siphash)
	return self
end


function HashRing_mt:__tostring()
	return string.format("levee.HashRing: %p", self)
end


function HashRing_mt:__gc()
	C.sp_ring_final(self)
end


function HashRing_mt:put(key, replicas, avail)
	local rc = C.sp_ring_put(self, key, #key, replicas or 1, avail or 1)
	if rc < 0 then return errors.get(rc) end
end


function HashRing_mt:get(key)
	local val = C.sp_ring_get(self, key, #key)
	if val == nil then return end
	return val
end


function HashRing_mt:del(key)
	return C.sp_ring_del(self, key, #key)
end


function HashRing_mt:find(val)
	local replica = C.sp_ring_find(self, val, #val)
	if replica == nil then return end
	return replica
end


function HashRing_mt:first()
	return C.sp_ring_next(self, nil)
end


function HashRing_mt:iter()
	return self:first():iter()
end


return ffi.metatype("SpRing", HashRing_mt)
