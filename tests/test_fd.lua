local FD = require("levee.fd")

local ffi = require("ffi")

ffi.cdef[[
int pipe(int pipefd[2]);
int write(int fd, const void *buf, int nbyte);
int read(int fd, const void *buf, int nbyte);
]]

local C = ffi.C

function pipe()
	local fds = ffi.new("int[2]")
	assert(C.pipe(fds) == 0)
	return fds[0], fds[1]
end

function write(fd, s)
	return C.write(fd, s, #s)
end

function read(fd, n)
	local buf = ffi.new("char[?]", n)
	local got = C.read(fd, buf, n)
	if got <= 0 then
		return got
	end
	return got, ffi.string(buf, got)
end



return {
	test_register = function()
		local levee = require("levee")

		levee.run(function(h)
			local r, w = pipe()
			r = FD(r)
			w = FD(w)
			r:nonblock(true)
			w:nonblock(true)

			local pollin = h:register(r.no, true)
			local _, pollout = h:register(w.no, nil, true)

			assert.True(pollout:recv())

			write(w.no, "x")
			assert.True(pollin:recv())

			-- trigger EAGAIN on write
			while true do
				local n = write(w.no, "x")
				if n == -1 then
					break
				end
			end
			assert.True(pollin:recv())

			read(r.no, 4096)
			assert.True(pollout:recv())
			assert.True(pollin:recv())

			-- trigger EAGAIN on read
			while true do
				local n = read(r.no, 4096)
				if n == -1 then
					break
				end
			end
			assert.True(pollout:recv())

			h:unregister(r.no)
			assert.equal(pollout:recv(), nil)
			h:unregister(w.no)
		end)
	end,
}
