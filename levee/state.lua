local ffi = require("ffi")
local C = ffi.C

local State_mt = {}
State_mt.__index = State_mt


function State_mt:load_file(path)
	-- TODO: handle errors
	C.levee_load_file(self, path)
end


function State_mt:load_string(str, name)
	-- TODO: handle errors
	C.levee_load_string(self, str, #str, name)
end


function State_mt:run(bg)
	C.levee_run(self, not not bg)
end


ffi.metatype("Levee", State_mt)


local function State()
	return ffi.gc(C.levee_create(), C.levee_destroy)
end


return State
