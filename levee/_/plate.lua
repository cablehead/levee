local lpeg = require("lpeg")

local P = lpeg.P
local S = lpeg.S
local V = lpeg.V
local C = lpeg.C
local Ct = lpeg.Ct


local WHITE = S(" \t\r\n") ^ 0

local VAR_BEGIN = P("{{") * WHITE
local VAR_END = WHITE * P("}}")
local VAR_MIDDLE = P((1-VAR_END)^0) / function(s) return {'SUB', {s}} end
local VAR = VAR_BEGIN * VAR_MIDDLE * VAR_END

local STMT_BEGIN = P("{%") * WHITE
local STMT_END = WHITE * P("%}")

local ELSE = STMT_BEGIN * P("else") * STMT_END
local END = STMT_BEGIN * P("end") * STMT_END

local IF_BEGIN = STMT_BEGIN * P("if ") * C(P((1-STMT_END)^0)) * STMT_END


local parse = Ct(P({
	"DOC",

	IF = (IF_BEGIN * Ct(V("BLOCK")) * P((ELSE * Ct(V("BLOCK")))^-1) * END
		) / function(var, block, else_block)
					return {"IF", {var, block, else_block}}
				end,

	TAG = VAR + V("IF"),
	NOT_TAG = P((1 - V("TAG"))^1),

	BLOCK = P((C(V("NOT_BLOCK_END")) + V("TAG"))^1),
	NOT_BLOCK_END = P((1 - (V("TAG") + ELSE + END))^1),

	DOC = P((C(V("NOT_TAG")) + V("TAG"))^1),
}))


local nodes = {}


function nodes.BLOCK(d, block)
	local ret = {}
	for __, v in ipairs(block) do
		if type(v) == "table" then
			local tree = nodes[v[1]](d, unpack(v[2]))
			if tree then
				if type(tree) == "table" then
					for __, sub_v in ipairs(tree) do
						table.insert(ret, sub_v)
					end
				else
					table.insert(ret, tree)
				end
			end
		else
			table.insert(ret, v)
		end
	end
	return ret
end


function nodes.SUB(d, var)
	return d[var]
end


function nodes.IF(d, var, block, else_block)
	if d[var] then
		return nodes.BLOCK(d, block)
	elseif else_block then
		return nodes.BLOCK(d, else_block)
	end
end


return function(s, d)
	d = d or {}
	local doc = parse:match(s)
	-- return nodes.BLOCK(d, doc)
	return table.concat(nodes.BLOCK(d, doc))
end
