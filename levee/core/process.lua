local ffi = require('ffi')
local C = ffi.C


local message = require("levee.core.message")
local _ = require("levee._")


--
-- Process

local Process_mt = {}
Process_mt.__index = Process_mt


function Process_mt:__tostring()
	local s
	if self:running() then
		s = "status=running"
	else
		s = ("status=done code=%s signal=%s"):format(self.exit_code, self.exit_sig)
	end
	return ("levee.Process: pid=%s %s"):format(self.pid, s)
end


function Process_mt:running()
	-- TODO:
	return not self.done.sender.value
end


function Process_mt:kill(signal)
	return C.kill(self.pid, signal or C.SIGTERM)
end


local function Process(hub, pid)
	return setmetatable({
		hub = hub,
		pid = pid,
		done = message.Pair(hub:value()), }, Process_mt)
end


-- Module interface
--

local M_mt = {}
M_mt.__index = M_mt


function M_mt:poweron()
	if self.sigchild then return end

	self.sigchild = self.hub:signal(C.SIGCHLD)

	self.hub:spawn(function()
		for no in self.sigchild do
			while true do
				local err, pid, code, sig = _.waitpid(-1, C.WNOHANG)
				if err then print("TODO:", err, pid) end
				if not pid then break end
				local child = self.children[pid]
				if child then
					self.children[pid] = nil
					child.exit_code = code
					child.exit_sig = sig
					child.done:send(child)
				end
			end
		end
	end)
end


function M_mt:spawn(name, options)
	options = options or {}
	local io = options.io or {}

	self:poweron()  -- boot child reaper

	local in_r, in_w
	local out_r, out_w

	if not io.STDIN then
		err, in_r, in_w = _.pipe()
		assert(not err)
	end

	if not io.STDOUT then
		err, out_r, out_w = _.pipe()
		assert(not err)
	end

	local pid = C.fork()

	if pid > 0 then
		-- parent
		local child = Process(self.hub, pid)

		if not io.STDIN then
			_.close(in_r)
			_.fcntl_nonblock(in_w)
			child.stdin = self.hub.io:w(in_w)
		end

		if not io.STDOUT then
			_.close(out_w)
			_.fcntl_nonblock(out_r)
			child.stdout = self.hub.io:r(out_r)
		end

		self.children[pid] = child
		return child
	end

	local function to_no(no)
		if type(no) == "table" then
			-- assume this a levee io object
			no = no.no
			_.fcntl_block(no)
		end
		return no
	end

	-- child
	_.set_pdeathsig()

	if not io.STDIN then
		C.close(in_w)
		C.dup2(in_r, 0)
		C.close(in_r)
	else
		if io.STDIN == -1 then
			C.close(0)
		elseif io.STDIN ~= 0 then
			C.dup2(to_no(io.STDIN), 0)
		end
	end

	if not io.STDOUT then
		C.close(out_r)
		C.dup2(out_w, 1)
		C.close(out_w)
	else
		if io.STDOUT ~= 1 then C.dup2(to_no(io.STDOUT), 1) end
	end

	for no = 3, 65535 do
		local err, st = _.fstat(no)
		if st then
			_.fcntl(no, C.F_SETFD, 1LL)  -- FD_CLOEXEC needs to be a long
		end
	end

	-- clear blocked signals
	if ffi.os:lower() == "linux" then
		local sigset = ffi.new("sigset_t[1]")
		local rc = C.sigprocmask(C.SIG_SETMASK, sigset, nil)
		assert(rc == 0)
	else
		local SIG_DFL = ffi.cast("sighandler_t", 0)
		for no, _ in pairs(self.hub.signal.registered) do
			C.signal(no, SIG_DFL)
		end
	end

	local argv = options.argv or {}
	table.insert(argv, 1, name)
	local err = _.execvp(name, argv)
	assert(not err)
end


return function(hub)
	return setmetatable({hub = hub, children = {}}, M_mt)
end
