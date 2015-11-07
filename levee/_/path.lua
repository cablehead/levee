local ffi = require('ffi')
local C = ffi.C


local errors = require("levee.errors")


local _ = {}


local buflen = C.SP_PATH_MAX * 4
local buf = ffi.cast("char *", ffi.gc(C.malloc(buflen), C.free))
local ranges = ffi.new("SpRange16 [2]")
local procname = false
local procname_err, procname_val
local cwd = ffi.string(C.getcwd(buf, buflen))


function _.cwd(s)
	if s then
		s = _.join(cwd, s)
		local rc = C.chdir(s)
		if rc < 0 then return errors.get(ffi.errno()) end
		cwd = s
	end
	return nil, cwd
end


function _.abs(s)
	return _.join(cwd, s)
end


function _.real(s)
	local p = C.realpath(s, buf)
	if p == nil then return errors.get(ffi.errno()) end
	return nil, ffi.string(p)
end


function _.pop(s, n)
	local rng = ranges[0]
	rng.off = 0
	rng.len = #s
	C.sp_path_pop(s, rng, n or 1)
	return s:sub(rng.off+1, rng.off+rng.len)
end


function _.split(s, n)
	local a, b = ranges[0], ranges[1]
	C.sp_path_split(a, b, s, #s, n or 1)
	return
		s:sub(a.off+1, a.off+a.len),
		s:sub(b.off+1, b.off+b.len)
end


function _.splitext(s)
	local a, b = ranges[0], ranges[1]
	C.sp_path_splitext(a, b, s, #s)
	return
		s:sub(a.off+1, a.off+a.len),
		s:sub(b.off+1, b.off+b.len)
end


function _.join(s, ...)
	local n = #s
	C.memcpy(buf, s, n)
	buf[n] = 0
	for i, p in ipairs({...}) do
		n = C.sp_path_join(buf, buflen, buf, n, p, #p, 0)
		if n < 0 then return "" end
		buf[n] = 0
	end
	n = C.sp_path_clean(buf, n, 0)
	return ffi.string(buf, n)
end


function _.clean(s)
	C.memcpy(buf, s, #s)
	buf[#s] = 0
	local n = C.sp_path_clean(buf, #s, 0)
	return ffi.string(buf, n)
end


function _.match(s, m)
	return C.sp_path_match(s, m)
end


function _.dirname(s, n)
	local a, b = ranges[0], ranges[1]
	C.sp_path_split(a, b, s, #s, n or 1)
	return s:sub(a.off+1, a.off+a.len)
end


function _.basename(s, n)
	local a, b = ranges[0], ranges[1]
	C.sp_path_split(a, b, s, #s, n or 1)
	return s:sub(b.off+1, b.off+b.len)
end


function _.procname()
	if not procname then
		local n = C.sp_path_proc(buf, buflen)
		if n < 0 then
			procname_err = errors.get(n)
		else
			procname_val = ffi.string(buf, n)
		end
		procname = true
	end
	return procname_err, procname_val
end


function _.envname(s)
	local n = C.sp_path_env(s, buf, buflen)
	if n < 0 then return errors.get(n) end
	return nil, ffi.string(buf, n)
end


return _
