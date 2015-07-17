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
				print("WATCH", pid, code, sig)
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


function M_mt:adopt(pid)
	self.children[pid] = Process(self.hub, pid)
	return self.children[pid]
end


function M_mt:launch(f, ...)
	-- boot child reaper
	self:poweron()

	local pid = C.fork()

	-- parent
	if pid > 0 then return self:adopt(pid) end

	-- child
	f(...)
end


function M_mt:execlp(name, ...)
	return self:launch(sys.process.execlp, name, ...)
end


return function(hub)
	return setmetatable({hub = hub, children = {}}, M_mt)
end
