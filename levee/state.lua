local ffi = require("ffi")
local C = ffi.C

local State_mt = {}
State_mt.__index = State_mt


local function check(self, ok)
	if ok then
		return true
	end
	return false, ffi.string(C.levee_get_error(self))
end


function State_mt:load_file(path)
	return check(self, C.levee_load_file(self, path))
end


function State_mt:load_string(str, name)
	return check(self, C.levee_load_string(self, str, #str, name))
end


function State_mt:load_function(fn)
	-- TODO: what should the name be?
	return self:load_string(string.dump(fn), "main")
end


function State_mt:push(val)
	if type(val) == "number" then
		C.levee_push_number(self, val)
	elseif type(val) == "string" then
		C.levee_push_number(self, val, #val)
	end
end


function State_mt:pop(n)
	C.levee_pop(self, n or 1)
end


function State_mt:run(narg, bg)
	return check(self, C.levee_run(self, narg, not not bg))
end


ffi.metatype("Levee", State_mt)


local function State()
	return ffi.gc(C.levee_create(), C.levee_destroy)
end


return State
