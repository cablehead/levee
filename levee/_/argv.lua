local io = require('io')
local os = require('os')
local ffi = require('ffi')
C = ffi.C

local Argv_mt = {}
Argv_mt.__index = Argv_mt


function Argv_mt:exit(fmt, ...)
	local msg
	if fmt then
		msg = string.format(fmt, ...)
	end
	if self.exit_cb then
		self.exit_cb(self.idx, self.opt, msg)
	else
		if self.opt then
			io.stderr:write(string.format("invalid option '%s'", self.opt))
		else
			io.stderr:write(string.format("invalid argument #%d", self.idx))
		end
		if msg then
			io.stderr:write(string.format(": %s", msg))
		end
		io.stderr:write("\n")
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


function Argv_mt:is_option()
	if not self:more() then return end
	local arg = self.args[self.idx]
	-- match long option: --long-value
	if arg:match("^%-%-(.*)") then return true end
		-- match short options: -xyz
	if arg:match("^%-(.+)") then return true end
	return false
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
			self.optshort = false
			self.idx = self.idx + 1
			self.opt = optrem -- save active option
			return optrem
		end

		-- match short options: -xyz
		optrem = arg:match("^%-(.+)")
		if optrem then
			self.optshort = true
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
		self.optshort = false
	end
	self.opt = ch -- save active option
	return ch
end


function Argv_mt:argn(n)
	local args = {}
	if not self.optrem then
		while self.idx + #args <= self.idxstop and #args < n do
			local value = self.args[self.idx + #args]
			if value:sub(1,1) == '-' then
				break
			end
			table.insert(args, value)
		end
	end
	if #args < n then
		return self:exit("expected %d argument(s)", n)
	end
	self.idx = self.idx + #args
	return args
end


function Argv_mt:remain()
	local keys = {}
	for k in pairs(self.args) do table.insert(keys, k) end
	table.sort(keys)

	local remain = {}
	for __, i in ipairs(keys) do remain[i-self.idx+1] = self.args[i] end
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
	end, "readable file expected")
end


function Argv_mt:inputfd(defult)
	return self:next(function(val)
		if val == '-' then
			return default or 0
		else
			local fd = C.open(val, C.O_RDONLY)
			if fd < 0 then fd = nil end
			return fd
		end
	end, "readable file expected")
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


function Argv_mt:outputfd(defult)
	return self:next(function(val)
		if val == '-' then
			return default or 1
		else
			local fd = C.open(val, C.O_WRONLY)
			if fd < 0 then fd = nil end
			return fd
		end
	end, "writable file expected")
end


function Argv_mt:commands(usage, commands, ...)
	--[[
  commands is table of
    command name = {
      short = a short string description of the command (optional)

      usage = function that should return a string description of the
              command's usage

      parse = function that takes an argv table an returns a table of options
              or an integer, in which case the command's usage will be
              displayed and the program will exit with that exit code

      run   = function that takes the options from parse and performs the
              command
	--]]

	local function exit()
		usage = {usage, "\n\nAvailable commands are:\n", }

		local order = commands.__order
		local len = 0
		if order then
			for i, k in ipairs(order) do len = math.max(len, #k) end
		else
			order = {}
			for k, v in pairs(commands) do
				len = math.max(len, #k)
				table.insert(order, k)
			end
		end

		for i, k in ipairs(order) do
			if not commands[k].__hide then
				table.insert(usage, "    "..k)
				local short = commands[k].short
				if short then
					local spacer = " "
					for i = 1, len - #k do
						spacer = spacer .. " "
					end
					table.insert(usage, spacer .. "- ")
					table.insert(usage, short)
				end
				table.insert(usage, "\n")
			end
		end

		-- dang, i wonder if we can rework exit to not prepend a message...
		-- self:exit(table.concat(usage))
		io.stderr:write(table.concat(usage))
		os.exit(1)
	end

	if not self:more() then exit() end

	local name = self:next()
	if name == "-h" or name == "--help" then exit() end

	local command = commands[name]
	if not command then
		io.stderr:write("unknown command: " .. name .. "\n")
		os.exit(1)
	end

	local nxt = self:peek()
	if nxt == "-h" or nxt == "--help" then
		io.stderr:write(command.usage() .. "\n")
		os.exit(1)
	end

	local options = command.parse(self)
	if not options then
		io.stderr:write(command.usage() .. "\n")
		os.exit(1)
	end

	return command.run(options, ...)
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
