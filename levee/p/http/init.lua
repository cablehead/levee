local prefix = "levee.p.http."
local default = require(prefix.."0_3")
local mods = {
	["0_4"]=require(prefix.."0_4"),
	parse=require(prefix.."parse"),
	status=require(prefix.."status"),
}

local Version_mt = {}

function Version_mt:__index(key)
	if mods[key] then return mods[key] end
	return default[key]
end

Version_mt.__call =  default.__call

return setmetatable({}, Version_mt)
