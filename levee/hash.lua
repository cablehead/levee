local ffi = require('ffi')
local C = ffi.C

local metro_seed = math.random(4294967295)
print(metro_seed)

local function crc32(val, len)
	return C.sp_crc32(0ULL, val, len or #val)
end

local function crc32c(val, len)
	return C.sp_crc32c(0ULL, val, len or #val)
end

local function metro(val, len, seed)
	return C.sp_metrohash64(val, len or #val, seed or metro_seed)
end

return {
	crc32 = crc32,
	crc32c = crc32c,
	metro = metro
}
