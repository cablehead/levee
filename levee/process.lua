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

function M_mt:spawn(name, argv, options)
	options = options or {}
	local io = options.io or {}

	self:poweron()  -- boot child reaper

	local in_r, in_w
	local out_r, out_w

	if not io.STDIN then
		in_r, in_w = sys.os.pipe()
	end

	if not io.STDOUT then
		out_r, out_w = sys.os.pipe()
	end

	local pid = C.fork()

	if pid > 0 then
		-- parent
		local child = Process(self.hub, pid)

		if not io.STDIN then
			C.close(in_r)
			child.stdin = self.hub.io:w(in_w)
		end

		if not io.STDOUT then
			C.close(out_w)
			child.stdout = self.hub.io:r(out_r)
		end

		self.children[pid] = child
		return child
	end

	-- child
	if not io.STDIN then
		C.close(in_w)
		C.dup2(in_r, 0)
		C.close(in_r)
	else
		C.dup2(io.STDIN, 0)
	end

	if not io.STDOUT then
		C.close(out_r)
		C.dup2(out_w, 1)
		C.close(out_w)
	else
		C.dup2(io.STDOUT, 1)
	end

	for no = 3, 65535 do
		local st = sys.os.fstat(no)
		if st then C.close(no) end
	end

	local argv = argv or {}
	table.insert(argv, 1, name)
	local rc = sys.process.execvp(name, argv)
	assert(rc == 0)
end


return function(hub)
	return setmetatable({hub = hub, children = {}}, M_mt)
end
