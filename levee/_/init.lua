local ret = {
	argv = require("levee._.argv"),
}

for k, v in pairs(require("levee._.os")) do
	ret[k] = v
end

return ret
