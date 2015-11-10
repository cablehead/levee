local math = require('math')
local io = require('io')
local os = require('os')

local _ = require("levee._")


--
-- some local functions

local function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local Source_mt = {}
Source_mt.__index = Source_mt

function Source_mt:lines(s, e)
	local lines = self._lines
	if not lines then
		lines = {}
		for l in self.path:lines() do
			table.insert(lines, l)
		end
		self._lines = lines
	end
	s = math.max(1, s or 1)
	e = math.min(#lines, e or #lines)
	return function()
		if s <= e then
			local i = s
			s = s + 1
			return i, lines[i]
		end
	end
end

function Source_mt:line(no)
	local no, s = self:lines(no, no + 1)()
	return s
end

local function Source(path)
	return setmetatable({path = io.open(_.path.abs(path))}, Source_mt)
end

local function traceback(n, m)
	local trace = {}

	local level = 1

	while true do
		local info = debug.getinfo(level, "Sl")
		if not info then break end

		if info.what == "Lua" then
			table.insert(trace, info)
		end
		level = level + 1
	end

	local s= {}
	-- for i = #trace, 1, -1 do
	for i = #trace - 3, 1, -1 do
		local info = trace[i]
		if _.path.basename(info.short_src) == "test.lua" then break end
		table.insert(s, tostring(info.short_src))
		table.insert(s, ": ")
		table.insert(s, tostring(info.currentline))
		table.insert(s, "\n")
		table.insert(s, "  --> "..
			trim(Source(info.short_src):line(info.currentline)))
		table.insert(s, "\n")
		table.insert(s, "\n")
	end
	return table.concat(s)
end


--
-- setup global variables

debug = require('debug')

local Assert_mt = {}
Assert_mt.__index = Assert_mt

local _assert = assert

function Assert_mt.__call(self, ...)
	return _assert(...)
end

function Assert_mt.equal(want, got)
	if want ~= got then
		error(("%s ~= %s"):format(repr(want), repr(got)))
	end
end

Assert_mt.equals = Assert_mt.equal

local function deepcompare(t1, t2, ignore_mt)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then return false end
  -- non-table types can be directly compared
  if ty1 ~= 'table' then return t1 == t2 end
  local mt1 = debug.getmetatable(t1)
  local mt2 = debug.getmetatable(t2)
  -- would equality be determined by metatable __eq?
  if mt1 and mt1 == mt2 and mt1.__eq then
    -- then use that unless asked not to
    if not ignore_mt then return t1 == t2 end
  else -- we can skip the deep comparison below if t1 and t2 share identity
    if t1 == t2 then return true end
  end
  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not deepcompare(v1,v2) then return false end
  end
  for k2,_ in pairs(t2) do
		-- only check whether each element has a t1 counterpart, actual comparison
    -- has been done in first loop above
    if t1[k2] == nil then return false end
  end
  return true
end

function Assert_mt.same(want, got)
	if type(want) == "table" and type(got) == "table" then
		if not deepcompare(want, got, true) then
			error(("values differ:\n\n%s\n\n%s\n"):format(repr(want), repr(got)))
		end
		return true
	end
	Assert_mt.equal(want, got)
end

function Assert_mt.error(f)
	local ok = pcall(f)
	if ok then
		error("error expected.")
	end
end

function Assert_mt.is_nil(got)
	if got ~= nil then
		error(("%s is not nil"):format(tostring(got)))
	end
end

assert = setmetatable({}, Assert_mt)

local function repr(x, indent)
	indent = indent or ""
	local s
	if type(x) == "table" then
		s = "{\n"
		local i, v = next(x)
		while i do
			s = s .. indent .. "    " .. repr(i) .. " = " .. repr(v, indent.."    ")
			i, v = next(x, i)
			if i then s = s .. ",\n" end

		end
		return s .. "}"

	elseif type(x) == "string" then
		return '"'..x..'"'

	else
		return tostring(x)
	end
end

local function x(s, n)
	ret = {}
	for _ = 1, n do
		table.insert(ret, s)
	end
	return table.concat(ret)
end


--
-- colors

local txtblk='\27[0;30m' -- Black - Regular
local txtred='\27[0;31m' -- Red
local txtgrn='\27[0;32m' -- Green
local txtylw='\27[0;33m' -- Yellow
local txtblu='\27[0;34m' -- Blue
local txtpur='\27[0;35m' -- Purple
local txtcyn='\27[0;36m' -- Cyan
local txtwht='\27[0;37m' -- White
local bldblk='\27[1;30m' -- Black - Bold
local bldred='\27[1;31m' -- Red
local bldgrn='\27[1;32m' -- Green
local bldylw='\27[1;33m' -- Yellow
local bldblu='\27[1;34m' -- Blue
local bldpur='\27[1;35m' -- Purple
local bldcyn='\27[1;36m' -- Cyan
local bldwht='\27[1;37m' -- White
local unkblk='\27[4;30m' -- Black - Underline
local undred='\27[4;31m' -- Red
local undgrn='\27[4;32m' -- Green
local undylw='\27[4;33m' -- Yellow
local undblu='\27[4;34m' -- Blue
local undpur='\27[4;35m' -- Purple
local undcyn='\27[4;36m' -- Cyan
local undwht='\27[4;37m' -- White
local bakblk='\27[40m'   -- Black - Background
local bakred='\27[41m'   -- Red
local bakgrn='\27[42m'   -- Green
local bakylw='\27[43m'   -- Yellow
local bakblu='\27[44m'   -- Blue
local bakpur='\27[45m'   -- Purple
local bakcyn='\27[46m'   -- Cyan
local bakwht='\27[47m'   -- White
local txtrst='\27[0m'    -- Text Reset

local COLORS = {
	PASS = txtgrn,
	SKIP = txtylw,
	FAIL = txtred, }


--
-- writer output convenience

local Writer_mt = {}
Writer_mt.__index = Writer_mt

function Writer_mt:__call(verbose, terse)
	if self.v then
		if verbose then io.write(verbose) end
	else
		if terse then io.write(terse) end
	end
	io.flush()
end

function Writer_mt:once(...)
	if not self.once then
		self(...)
		self.once = true
	end
end

function Writer_mt:notfirst(...)
	if self._notfirst then
		self(...)
	end
	self._notfirst = true
end

local function Writer(verbose)
	local self = setmetatable({}, Writer_mt)
	self.v = verbose
	return self
end


--
--

local function scan(path)
	local command = ('find %s -type f -name "*.lua"'):format(path)
	return io.popen(command):lines()
end


local function run_suite(options, suite)
	local M = assert(loadfile(suite))()
	local SKIP = (M.skipif or function() end)()

	local to_run = {}
	for name in pairs(M) do
		if name:sub(0, 5) == "test_" then
			if options.match and not string.find(name, options.match) then
			else
				table.insert(to_run, name)
			end
		end
	end

	if #to_run > 0 then
		table.sort(to_run)
		options.w:notfirst("\n")
		options.w(txtblu..suite..txtrst..'\n')
	end

	for i, name in ipairs(to_run) do
		local pattern = "    %-40s "
		options.w(pattern:format(name))

		local success, extra
		if SKIP then
			success, extra = true, "SKIP"
		else
			success, extra = xpcall(M[name],
				function(err)
					options.w(
						txtred..' FAIL'..txtrst..'\n\n'..
						'-----\n'..
						traceback()..
						err:match(":%d+: (.*)")
						..'\n-----\n')
					options.stats.FAIL = options.stats.FAIL + 1
				end)
		end
		if success and extra ~= 'IGNORE' then
			if not extra then extra = 'PASS' end
			options.w(
				(COLORS[extra] or txtred)..' '..extra..txtrst..'\n',
				extra == 'PASS' and '.' or extra:sub(1, 1))
			options.stats[extra] = options.stats[extra] + 1
		else
			if options.exitfirst then return end
		end
	end
end


--
-- command

return {
	usage = function()
		return "Usage: levee test [-v] [-x] [-k <match>] <path>"
	end,

	parse = function(argv)
		local options = {}

		while argv:more() do
			local opt = argv:option()

			if opt == "v" then options.verbose = 1
			elseif opt == "x" then options.exitfirst = 1
			elseif opt == "k" then options.match = argv:next()
			elseif opt == nil then
				if options.path then
					io.stderr:write("path already supplied\n")
					os.exit(1)
				end
				options.path = argv:next()
			else return end
		end

		if not options.path then
			io.stderr:write("path required\n")
			os.exit(1)
		end

		options.path = options.path:gsub("/$", "")

		return options
	end,

	run = function(options)
		_G.repr = repr
		_G.x = x
		_G.Writer = Writer
		_G.scan = scan

		local path = _.path.dirname(options.path)
		package.path = string.format(
			'./?/init.lua;%s/?.lua;%s/?/init.lua;%s/../?/init.lua;%s',
				path, path, path, package.path)

		options.w = Writer(options.verbose)
		options.stats = setmetatable({}, {__index = function() return 0 end})

		for suite in scan(options.path) do
			run_suite(options, suite)
			if options.exitfirst and options.stats.FAIL > 0 then break end
		end

		io.write('\n')
		for key, value in pairs(options.stats) do
			io.write(COLORS[key] or txtred, key, txtrst, '=', value, ' ')
		end
		io.write('\n')

		return options.stats.FAIL
	end,
}
