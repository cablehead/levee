local ffi = require('ffi')

return {
	test_socket = function()
		assert(ffi.sizeof("struct in_addr") == 4)
		assert(ffi.sizeof("struct in6_addr") == 16)
		assert(ffi.sizeof("struct sockaddr") == 16)
		assert(ffi.sizeof("struct sockaddr_storage") == 128)
		assert(ffi.sizeof("struct sockaddr_in") == 16)
		assert(ffi.sizeof("struct sockaddr_in6") == 28)
		if ffi.os == "Linux" then
			assert(ffi.sizeof("struct sockaddr_un") == 110)
		elseif ffi.os == "OSX" then
			assert(ffi.sizeof("struct sockaddr_un") == 106)
		else
			assert(false) -- unsupported os
		end
	end,
}
