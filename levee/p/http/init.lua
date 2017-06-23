local path = "levee.p.http."
local default = require(path.."0_3")
local mods = {
}

local Version_mt = {}

function Version_mt:__index(key)
	if mods[key] then return mods[key] end
	return default[key]
end

Version_mt.__call =  default.__call

return setmetatable({}, Version_mt)
