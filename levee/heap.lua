require("levee.cdef")

local ffi = require("ffi")
local C = ffi.C

local Errno = require('levee.errno')

local Heap = {}
Heap.__index = Heap


function Heap:__tostring()
	return string.format("levee.Heap: count=%d", #self)
end


function Heap:__len()
	return C.levee_heap_count(self.heap)
end


function Heap:push(pri, val)
	local id = #self.refs + 1
	self.refs[id] = val
	C.levee_heap_add(self.heap, pri, id)
end


function Heap:pop()
	local id = tonumber(C.levee_heap_remove(self.heap, C.LEVEE_HEAP_ROOT_KEY, 0))
	if id ~= 0 then
		local val = self.refs[id]
		self.refs[id] = nil
		return val
	end
end


function Heap:peek()
	local id = tonumber(C.levee_heap_get(self.heap, C.LEVEE_HEAP_ROOT_KEY, 0))
	if id ~= 0 then
		return self.refs[id]
	end
end


function Heap:clear()
	C.levee_heap_clear(self.heap)
	self.refs = {}
end


function Heap:popiter()
	return function()
		if #self > 0 then
			return self:pop()
		end
	end
end


function Heap:peekiter()
	local first = true
	return function()
		if first then
			first = false
		else
			self:pop()
		end
		if #self > 0 then
			return self:peek()
		end
	end
end

return function()
	local heap = C.levee_heap_create()
	if heap == nil then
		Errno:error("levee_heap_create")
	end
	ffi.gc(heap, C.levee_heap_destroy)
	return setmetatable({heap = heap, refs = {}}, Heap)
end
