local ffi = require('ffi')
local C = ffi.C

local Buffer = require("levee.d.buffer")


local tmp_iov = ffi.new("struct iovec[1]")
local tmp_buf = Buffer()


--
-- Map
-- TODO: redo the scatter/scatter_count interface


local Map_mt = {}


function Map_mt:__tostring()
	local n = C.sp_http_map_encode_size(self)
	tmp_buf:ensure(n)
	local buf = tmp_buf:tail()
	C.sp_http_map_encode(self, buf)
	tmp_buf:bump(n)
	return tmp_buf:take(n)
end


local function map_add(self, name, value)
	C.sp_http_map_put(self, name, #name, value, #value)
end


local function map_value(entry, idx)
	if C.sp_http_entry_value(entry, idx-1, tmp_iov) then
		return ffi.string(tmp_iov[0].iov_base, tmp_iov[0].iov_len)
	end
end


local function map_writeinto_iovec(self, iov)
	local n = C.sp_http_map_scatter_count(self)
	iov:ensure(n)
	C.sp_http_map_scatter(self, iov.iov + iov.n)
	iov:bump(n, C.sp_http_map_encode_size(self))
end


function Map_mt:__index(key)
	if key == "add" then return map_add end
	if key == "writeinto_iovec" then return map_writeinto_iovec end

	local e = C.sp_http_map_get(self, key, #key)
	local n = C.sp_http_entry_count(e)
	if n == 1 then
		return map_value(e, 1)
	elseif n > 1 then
		local list = {}
		for i=1,tonumber(n) do
			list[i] = map_value(e, i)
		end
		return list
	end
end


function Map_mt:__newindex(key, val)
	C.sp_http_map_del(self, key, #key)
	if type(val) == "table" then
		for _,v in ipairs(val) do
			map_add(self, key, v)
		end
	elseif val then
		map_add(self, key, val)
	end
end


local function Map(t)
	local m = ffi.gc(C.sp_http_map_new(), C.sp_http_map_free)
	if t then
		for k,v in pairs(t) do
			m:set(k, v)
		end
	end
	return m
end


ffi.metatype("SpHttpMap", Map_mt)


return Map
