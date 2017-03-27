local ffi = require('ffi')
local C = ffi.C

local errors = require("levee.errors")


local _ = {}


_.stat = require("levee._.syscalls").stat


local buflen = C.SP_PATH_MAX * 4
local buf = ffi.cast("char *", C.malloc(buflen))
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


function _.exists(name)
  local ffi = require("ffi")
  local C = ffi.C
  local rc = C.access(name, C.F_OK)
  return rc ~= -1
end


function _.walk(path, depth)
	local err, dir = _.Dir(path, depth)
	if err then return function() end end
	return function()
		local rc = C.sp_dir_next(dir)
		if rc > 0 then return dir end
	end
end


--
-- Path

local Path_mt = {}
Path_mt.__index = Path_mt


function Path_mt:__tostring()
	return self._path
end

function Path_mt:__concat(s)
	return tostring(self) .. tostring(s)
end


function Path_mt:exists()
	return _.exists(self._path)
end


function Path_mt:remove(recurse)
	local __, __, rc = os.execute(("rm %s%s 2>/dev/null"):format(
		recurse and "-r " or "", self))
	return rc == 0
end


function Path_mt:stat()
	local err, stat = _.stat(self._path)
	return stat
end


function Path_mt:is_dir()
	local err, stat = _.stat(self._path)
	if not stat then return end
	return stat:is_dir()
end


function Path_mt:walk(depth)
	return _.walk(self._path, depth)
end


function Path_mt:cwd()
	local err, cwd = _.cwd(self._path)
	if err then err:exit() end
	return cwd
end


function Path_mt:write(s)
	local fh = io.open(self._path, "w")
	fh:write(s)
	fh:close()
end


function Path_mt:__call(rel)
	return setmetatable({_path=_.join(self._path, rel)}, Path_mt)
end


local Path_constructor = {}
Path_constructor.__index = Path_constructor


function Path_constructor:__call(path)
	return setmetatable({_path=_.abs(path)}, Path_mt)
end


function Path_constructor:tmpdir()
	local path = os.tmpname()
	os.remove(path)
	os.execute("mkdir " .. path)
	return setmetatable({_path=_.abs(path)}, Path_mt)
end


_.Path = setmetatable({}, Path_constructor)


--
-- Dir


local Dir_mt = {}
Dir_mt.__index = Dir_mt


function Dir_mt:__tostring()
	return "levee._.Dir: " .. self:pathname()
end


-- don't descend into the directory on the subsequent `next`
function Dir_mt:skip()
	C.sp_dir_skip(self)
end


-- follow into a symlink when calling the subsequent `next`
function Dir_mt:follow()
	C.sp_dir_follow(self)
end


function Dir_mt:type()
	return C.sp_dir_type(self)
end


function Dir_mt:is_reg()
	return C.sp_dir_type(self) == C.SP_PATH_REG
end


function Dir_mt:is_dir()
	return C.sp_dir_type(self) == C.SP_PATH_DIR
end


function Dir_mt:stat()
	local src = C.sp_dir_stat(self)
	if src == nil then return errors.get(-ffi.errno()) end
	local dst = ffi.new("SpStat")
	C.memcpy(dst, src, ffi.sizeof(dst))
	return nil, dst
end


function Dir_mt:pathname()
	return ffi.string(self.path, self.pathlen)
end


function Dir_mt:dirname()
	return ffi.string(self.path, self.dirlen)
end


function Dir_mt:basename()
	return ffi.string(self.path + self.dirlen + 1, self.pathlen - self.dirlen - 1)
end


local Dir_ct = ffi.metatype("SpDir", Dir_mt)


function _.Dir(path, depth)
	local dir = Dir_ct()
	local rc = C.sp_dir_open(dir, path, depth or 255)
	if rc < 0 then return errors.get(rc) end
	return nil, ffi.gc(dir, C.sp_dir_close)
end


return _
