local ffi = require('ffi')
local C = ffi.C

local sys = require("levee.sys")


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
	return not self.done.closed
end


local function Process(hub, pid)
	return setmetatable({
		hub = hub,
		pid = pid,
		done = hub:pipe(),  -- TODO: we need a oneshot primitive
	}, Process_mt)
end


--
-- Module interface
--

local M_mt = {}
M_mt.__index = M_mt


function M_mt:poweron()
	if self.sigchild then return end

	self.sigchild = self.hub.signal(C.SIGCHLD)

	self.hub:spawn(function()
		for _ in self.sigchild do
			while true do
				local pid, code, sig = sys.process.waitpid(-1, C.WNOHANG)
				if pid <= 0 then break end
				local child = self.children[pid]
				if child then
					self.children[pid] = nil
					child.exit_code = code
					child.exit_sig = sig
					child.done:close()
				end
			end
		end
	end)
end


function M_mt:launch(options, f, ...)
	self:poweron()  -- boot child reaper

	local in_r, in_w
	local out_r, out_w

	if options.STDIN == C.CAPTURE then
		in_r, in_w = sys.os.pipe()
	end

	if options.STDOUT == C.CAPTURE then
		out_r, out_w = sys.os.pipe()
	end

	local pid = C.fork()

	if pid > 0 then
		-- parent
		local child = Process(self.hub, pid)

		if options.STDIN == C.CAPTURE then
			C.close(in_r)
			child.stdin = self.hub.io:w(in_w)
		end

		if options.STDOUT == C.CAPTURE then
			C.close(out_w)
			child.stdout = self.hub.io:r(out_r)
		end

		self.children[pid] = child
		return child
	end

	-- child
	if options.STDIN then
		if options.STDIN == C.CAPTURE then
			C.close(in_w)
			C.dup2(in_r, 0)
			C.close(in_r)
		else
			C.dup2(options.STDIN, 0)
		end
	end

	if options.STDOUT then
		if options.STDOUT == C.CAPTURE then
			C.close(out_r)
			C.dup2(out_w, 1)
			C.close(out_w)
		else
			C.dup2(options.STDOUT, 1)
		end
	end

	for i = 3, 65535 do
		local st = sys.os.fstat(i)
		if st then C.close(i) end
	end

	f(...)
end


function M_mt:execlp(options, name, ...)
	return self:launch(options, sys.process.execlp, name, ...)
end


return function(hub)
	return setmetatable({hub = hub, children = {}}, M_mt)
end
