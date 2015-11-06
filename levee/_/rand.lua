local os = require('os')
local ffi = require('ffi')
local C = ffi.C

local tmp_int = ffi.new("uint32_t [1]")
local tmp_num = ffi.new("double [1]")

local function bytes(len)
	local val = ffi.new("uint8_t [?]", len)
	if C.sp_rand(val, len) == 0 then
		return val
	end
end

local function integer(bound)
	if C.sp_rand_uint32(bound or 4294967295ULL, tmp_int) then
		return tmp_int[0]
	end
end

local function number()
	if C.sp_rand_double(tmp_num) then
		return tmp_num[0]
	end
end

return {
	bytes = bytes,
	integer = integer,
	number = number
}
