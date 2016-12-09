local ffi = require("ffi")

local errors = require("levee.errors")


local Parser_mt = {}
Parser_mt.__index = Parser_mt


function Parser_mt:init()
	C.sp_line_init(self)
end


function Parser_mt:next(stream)
	local buf, len = stream:value()

	local rc = C.sp_line_next(self, buf, len, false)
	if rc < 0 then return errors.get(rc) end

	if rc > 0 then
		local line = ffi.string(buf, rc - 1)
		stream:trim(rc)
		return nil, line
	end

	local err = stream:readin()
	if err then return err end
	return self:next(stream)
end


local Parser = ffi.metatype("SpLine", Parser_mt)


return {
	stream = function(stream, delim)
		-- stream methods:
		--	:readin()
		--	:value() -> returns char*, len (could return eof?)
		--	:trim(n)

		assert(not delim or delim == "\n")
		local p = Parser()
		p:init()
		return p:next(stream)
	end,
}
