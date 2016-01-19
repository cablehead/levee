local lpeg = require("lpeg")

local P = lpeg.P
local S = lpeg.S
local C = lpeg.C
local Ct = lpeg.Ct


return function(s, d)
	local function mapper(s)
		return d[s]
	end

	local WHITE = S(" \t\r\n") ^ 0
	local BEGIN_VAR = P("{{") * WHITE
	local END_VAR = WHITE * P("}}")
	local MIDDLE_VAR = P((1-END_VAR)^0) / mapper
	local VAR = BEGIN_VAR * MIDDLE_VAR * END_VAR
	local BODY = C(((1 - BEGIN_VAR)) ^ 0)
	local parse = Ct((BODY * VAR * BODY)^0)

	return table.concat(parse:match(s))
end
