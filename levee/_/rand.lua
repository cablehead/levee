local os = require('os')
local ffi = require('ffi')
local C = ffi.C

local pagesize = require("levee._").pagesize
local tmp_int = ffi.new("uint32_t [1]")
local tmp_num = ffi.new("double [1]")
local tmp_len = 0
local tmp_str = nil

local function bytes(len)
	local val = ffi.new("uint8_t [?]", len)
	if C.sp_rand(val, len) == 0 then
		return val
	end
end

local function string(len)
	if len > tmp_len then
		if len < pagesize then 
			tmp_len = pagesize
		else
			tmp_len = math.ceil(len / pagesize) * pagesize
		end
		tmp_str = ffi.cast("uint8_t *", ffi.gc(C.malloc(tmp_len), C.free))
	end
	if C.sp_rand(tmp_str, len) == 0 then
		return ffi.string(tmp_str, len)
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
	string = string,
	integer = integer,
	number = number
}
