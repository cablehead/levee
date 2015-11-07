local ret = {}


ret.argv = require("levee._.argv")
ret.time = require("levee._.time")
ret.poller = require("levee._.poller")
ret.path = require("levee._.path")

for i, k in ipairs({"dirname", "basename", "procname"}) do
	ret[k] = ret.path[k]
end

for k, v in pairs(require("levee._.syscalls")) do ret[k] = v end
for k, v in pairs(require("levee._.process")) do ret[k] = v end


return ret
