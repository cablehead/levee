local ffi = require("ffi")


return {
	stream = function(stream, delim)
		-- stream methods:
		--	:readin()
		--	:value() -> returns char*, len (could return eof?)
		--	:trim(n)

		delim = delim or "\n"
		local pos = 0

		while true do
			local buf, len = stream:value()

			local match = false
			while pos + #delim <= len do
				if ffi.string(buf+pos, #delim) == delim then
					match = true
					break
				end
				pos = pos + 1
			end

			if match then
				local line = ffi.string(buf, pos)
				stream:trim(pos+#delim)
				return nil, line
			end

			local err, n = stream:readin()
			if err then return err end
		end
	end,
}
