local ffi = require("ffi")
local C = ffi.C

local errors = require("levee.errors")


local ws = ffi.new("struct winsize[1]")


local term = {}


function term.winsize(no)
	local rc = C.ioctl(1, C.TIOCGWINSZ, ws)
	if rc < 0 then return errors.get(ffi.errno()) end
	return nil, {row=ws[0].ws_row, col=ws[0].ws_col}
end


return term
