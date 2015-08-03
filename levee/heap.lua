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
	local id
	if #self.avail > 0 then
		id = table.remove(self.avail)
	else
		id = #self.refs + 1
	end
	local item = C.levee_heap_add(self.heap, pri, id)
	self.refs[id] = {item, val}
end


function Heap:pop()
	local entry = C.levee_heap_get(self.heap, C.LEVEE_HEAP_ROOT_KEY)
	if entry ~= nil then
		local prio = entry.priority
		local id = tonumber(entry.item.value)
		C.levee_heap_remove(self.heap, C.LEVEE_HEAP_ROOT_KEY, 0)
		local val
		if id == #self.refs then
			val = table.remove(self.refs)
		else
			val = self.refs[id]
			self.refs[id] = false
			table.insert(self.avail, id)
		end
		return prio, val[2]
	end
end


function Heap:peek()
	local entry = C.levee_heap_get(self.heap, C.LEVEE_HEAP_ROOT_KEY)
	if entry ~= nil then
		return entry.priority, self.refs[tonumber(entry.item.value)][2]
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
	return setmetatable({heap = heap, refs = {}, avail={}}, Heap)
end
