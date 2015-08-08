local io = require('io')

local Argv_mt = {}
Argv_mt.__index = Argv_mt


function Argv_mt:more()
	return self.curr <= self.stop
end


function Argv_mt:peek()
	if self:more() then
		return self.args[self.curr]
	end
end


function Argv_mt:next(fn)
	if self.opt then return end
	local value
	if self:more() then
		value = self.args[self.curr]
		if fn then
			value = fn(value)
			if not value then return end
		end
		self.curr = self.curr + 1
	end
	return value
end


function Argv_mt:option()
	local opt = self.opt

	if not opt then
		if not self:more() then return end

		local arg = self.args[self.curr]

		-- match long option: --long-value
		opt = arg:match("^%-%-(.*)")
		if opt then
			self.curr = self.curr + 1
			return opt
		end

		-- match short options: -xyz
		opt = arg:match("^%-(.+)")
		if opt then
			self.curr = self.curr + 1
		end
	end

	-- split off the next character
	local ch = opt:sub(1, 1)
	opt = opt:sub(2)

	-- save the remaining 
	if #opt > 0 then
		self.opt = opt
	else
		self.opt = nil
	end
	return ch
end


function Argv_mt:list()
	if self.opt then return end
	local list = {}
	while self:more() do
		value = self.args[self.curr]
		if value:sub(1,1) == '-' then
			break
		end
		table.insert(list, value)
		self.curr = self.curr + 1
	end
	return list
end


function Argv_mt:remain()
	local remain = {unpack(self.args, self.curr)}
	remain[0] = self.args[0]
	return remain
end


function Argv_mt:number()
	return self:next(function(val)
		return tonumber(val)
	end)
end


function Argv_mt:file(mode)
	return self:next(function(val)
		return io.open(val, mode)
	end)
end


function Argv_mt:input(defult)
	return self:next(function(val)
		if val == '-' then
			return default or io.stdin
		else
			return io.open(val, "r")
		end
	end)
end


function Argv_mt:output(defult)
	return self:next(function(val)
		if val == '-' then
			return default or io.stdout
		else
			return io.open(val, "w")
		end
	end)
end


return function(args, start, stop)
	start = start or 1
	stop = stop or #args
	return setmetatable({args=args, start=start, stop=stop, curr=start}, Argv_mt)
end

