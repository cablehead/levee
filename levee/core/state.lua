local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
struct LeveeState {
	Levee *child;
};
]]

local State_mt = {}
State_mt.__index = State_mt


local access_error = "invalid access of background state"
local sender_type = ffi.typeof("LeveeChanSender *")


local function check(child, ok)
	if ok then
		return true
	end
	return false, ffi.string(C.levee_get_error(child))
end


function State_mt:__new()
	local state = ffi.new(self)
	state.child = C.levee_create()
	return state
end


function State_mt:__gc()
	if self.child then
		C.levee_destroy(self.child)
		self.child = nil
	end
end


function State_mt:__tostring()
	return string.format("levee.State: %p", self)
end


function State_mt:load_file(path)
	if self.child == nil then
		return false, access_error
	end
	return check(self.child, C.levee_load_file(self.child, path))
end


function State_mt:load_string(str, name)
	if self.child == nil then
		return false, access_error
	end
	return check(self.child, C.levee_load_string(self.child, str, #str, name))
end


function State_mt:load_function(fn)
	-- TODO: what should the name be?
	return self:load_string(string.dump(fn), "main")
end


function State_mt:push(val)
	if self.child == nil then
		return
	end
	if type(val) == "number" then
		C.levee_push_number(self.child, val)
	elseif type(val) == "string" then
		C.levee_push_string(self.child, val, #val)
	elseif type(val) == "boolean" then
		C.levee_push_bool(self.child, val)
	elseif type(val) == "cdata" and ffi.typeof(val) == sender_type then
		C.levee_push_sender(self.child, val)
	else
		C.levee_push_nil(self.child)
	end
end


function State_mt:pop(n)
	if self.child == nil then
		return
	end
	C.levee_pop(self.child, n or 1)
end


function State_mt:run(narg, bg)
	if self.child == nil then
		return false, access_error
	end
	local child = self.child
	if bg then
		self.child = nil
	end
	return check(child, C.levee_run(child, narg, not not bg))
end


local State = ffi.metatype("struct LeveeState", State_mt)


return State
