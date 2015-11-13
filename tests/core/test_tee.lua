local ffi = require('ffi')
local C = ffi.C

local levee = require("levee")


local function make_pipe(h, drain)
	local err, r, w = h.io:pipe()
	if drain then
		h:spawn(function()
			while true do
				local err = r:stream():readin()
				if err then break end
			end
		end)
	end
	return {r = r, w = w}
end


return {
	test_small = function()
		local h = levee.Hub()
		local pre = ("."):rep(10)
		local val = ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"):rep(512)
		local crc = C.sp_crc32c(0ULL, pre, #pre)
		crc = C.sp_crc32c(crc, val, #val - 10)

		local input = make_pipe(h, false)
		local pipes = {
			p1 = make_pipe(h, true),
			p2 = make_pipe(h, true),
			p3 = make_pipe(h, true)
		}

		local s = input.r:stream()
		input.w:write(pre)
		s:readin()
		h:spawn(function()
			input.w:write(val)
			input.w:write(val)
			input.w:write(val)
			input.w:write(val)
		end)

		local sender, recver = h:pipe()

		local c = s:chunk(64*512*4)
		h:spawn(function()
			c:tee(pipes.p1.w, pipes.p2.w, pipes.p3.w, function(chunks)
				for chunk in chunks do
					sender:send(chunk)
				end
				sender:close()
			end)
		end)

		for chunk in recver do
			print(chunk.len)
			chunk:discard()
		end
	end
}
