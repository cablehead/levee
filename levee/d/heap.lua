local ffi = require("ffi")
local C = ffi.C


local REFS = {}


local function castptr(cdata)
	return tonumber(ffi.cast("uintptr_t", cdata))
end


local HeapItem_mt = {}
HeapItem_mt.__index = HeapItem_mt


function HeapItem_mt:__tostring()
	return string.format("levee.HeapItem: key=%d", self.key)
end


function HeapItem_mt:update(pri)
	C.levee_heap_update(self.heap, self.key, pri)
end


function HeapItem_mt:remove()
	C.levee_heap_remove(self.heap, self.key)

	local entry = C.levee_heap_get(self.heap, self.key)

	print()
	print()
	print(ffi.sizeof(self.heap))
	local i = tonumber(ffi.cast("uintptr_t", self.heap))
	print(i)
	print(i)
	print(i)
	print(i)

	local m = {}
	m[i] = "foo"
	do return end
	if entry == nil then return false end

	local id = tonumber(entry.item.value)
	print(id)

	self.heap.refs[id] = false
	table.insert(self.heap.avail, id)
	return true

end


ffi.metatype("LeveeHeapItem", HeapItem_mt)


local Heap_mt = {}
Heap_mt.__index = Heap_mt


function Heap_mt:__tostring()
	return string.format("levee.Heap: count=%d", #self)
end


function Heap_mt:__len()
	return C.levee_heap_count(self)
end


function Heap_mt:push(pri, val)
	local item = C.levee_heap_add(self, pri)
	REFS[castptr(self)][castptr(item)] = val
	return item
end


function Heap_mt:pop()
	local entry = C.levee_heap_get(self, C.LEVEE_HEAP_ROOT_KEY)
	if entry ~= nil then
		local ptr = castptr(entry.item)
		local prio = entry.priority
		C.levee_heap_remove(self, C.LEVEE_HEAP_ROOT_KEY)
		local val = REFS[castptr(self)][ptr]
		REFS[castptr(self)][ptr] = nil
		return prio, val
	end
end


function Heap_mt:peek()
	local entry = C.levee_heap_get(self, C.LEVEE_HEAP_ROOT_KEY)
	if entry ~= nil then
		return entry.priority, REFS[castptr(self)][val]
	end
end


function Heap_mt:clear()
	C.levee_heap_clear(self)
	assert(false)
end


function Heap_mt:popiter()
	return function()
		if #self > 0 then
			return self:pop()
		end
	end
end


function Heap_mt:peekiter()
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


function Heap_mt:refs()
	return REFS[castptr(self)]
end


function Heap_mt:__gc()
	print("__GC")
	C.levee_heap_destroy(self)
	REFS[castptr(self)] = nil
end


ffi.metatype("LeveeHeap", Heap_mt)


return {
	REFS = REFS,

	Heap = function()
		local self = C.levee_heap_create()
		if self == nil then error("levee_heap_create") end
		REFS[castptr(self)] = {}
		return self
	end,
}
