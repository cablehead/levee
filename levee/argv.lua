local io = require('io')
local os = require('os')

local Argv_mt = {}
Argv_mt.__index = Argv_mt


function Argv_mt:exit(fmt, ...)
	local msg = string.format(fmt, unpack{...})
	if self.exit_cb then
		self.exit_cb(self.idx, self.opt, msg)
	else
		if self.opt then
			io.stderr:write(string.format("invalid option '%s': %s\n", self.opt, msg))
		else
			io.stderr:write(string.format("invalid argument #%d: %s\n", self.idx, msg))
		end
		os.exit(1)
	end
end


function Argv_mt:more()
	return self.idx <= self.idxstop
end


function Argv_mt:peek()
	if self:more() then
		return self.args[self.idx]
	end
end


function Argv_mt:next(fn, msg)
	if self.optrem or not self:more() then
		return self:exit(msg)
	end
	local value = self.args[self.idx]
	if fn then
		value = fn(value)
		if not value then
			return self:exit(msg)
		end
	end
	self.idx = self.idx + 1
	return value
end


function Argv_mt:option()
	local optrem = self.optrem
	self.opt = nil

	if not optrem then
		if not self:more() then return end

		local arg = self.args[self.idx]

		-- match long option: --long-value
		optrem = arg:match("^%-%-(.*)")
		if optrem then
			self.idx = self.idx + 1
			self.opt = optrem -- save active option
			return optrem
		end

		-- match short options: -xyz
		optrem = arg:match("^%-(.+)")
		if optrem then
			self.idx = self.idx + 1
		end

		-- no option format matched
		if not optrem then return end
	end

	-- split off the next character
	local ch = optrem:sub(1, 1)
	optrem = optrem:sub(2)

	-- save the remaining 
	if #optrem > 0 then
		self.optrem = optrem
	else
		self.optrem = nil
	end
	self.opt = ch -- save active option
	return ch
end


function Argv_mt:list(min, max)
	if self.optrem then return end
	local list = {}
	while self.idx + #list <= self.idxstop do
		local value = self.args[self.idx + #list]
		if value:sub(1,1) == '-' then
			break
		end
		table.insert(list, value)
		if max and #list == max then
			break
		end
	end
	if min and #list < min then
		self:exit("list expected at least %d item(s)", min)
		return
	end
	self.idx = self.idx + #list
	return list
end


function Argv_mt:remain()
	local remain = {unpack(self.args, self.idx)}
	remain[0] = self.args[0]
	return remain
end


function Argv_mt:number()
	return self:next(function(val)
		return tonumber(val)
	end, "number expected")
end


function Argv_mt:file(mode)
	return self:next(function(val)
		return io.open(val, mode)
	end, "file expected")
end


function Argv_mt:input(defult)
	return self:next(function(val)
		if val == '-' then
			return default or io.stdin
		else
			return io.open(val, "r")
		end
	end, "readablefile expected")
end


function Argv_mt:output(defult)
	return self:next(function(val)
		if val == '-' then
			return default or io.stdout
		else
			return io.open(val, "w")
		end
	end, "writable file expected")
end


return function(args, start, stop, exit)
	if type(exit) ~= "function" then
		if type(stop) == "function" then
			exit = stop
			stop = nil
		elseif type(start) == "function" then
			exit = start
			start = nil
			stop = nil
		end
	end
	start = start or 1
	stop = stop or #args
	exit = exit or arg_exit
	return setmetatable({
		args = args,
		idx = start, idxstart = start, idxstop = stop,
		exit_cb = exit
	}, Argv_mt)
end

