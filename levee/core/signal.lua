

local Signal_mt = {}
Signal_mt.__index = Signal_mt


function Signal_mt:__call(hub, ...)
	local sender, recver = self.hub:queue()
	self.reverse[sender] = {}

	local sigs = {...}
	for i = 1, #sigs do
		local no = sigs[i]

		if not self.registered[no] then
			self.hub.poller:signal_register(no)
			self.registered[no] = {}
		end

		self.registered[no][sender] = 1
		table.insert(self.reverse[sender], no)
	end

	recver.on_close = function() self:unregister(sender) end
	return recver
end


function Signal_mt:unregister(sender)
	local sigs = self.reverse[sender]
	for i = 1, #sigs do
		local no = sigs[i]
		self.registered[no][sender] = nil

		if not next(self.registered[no]) then
			self.hub.poller:signal_unregister(no)
			self.registered[no] = nil
		end
	end
	self.reverse[sender]= nil
end


function Signal_mt:trigger(no)
	self.hub.poller:signal_clear(no)
	for sender, _ in pairs(self.registered[no]) do
		sender:send(no)
	end
end


local function Signal(hub)
	return setmetatable({hub = hub, registered = {}, reverse = {}}, Signal_mt)
end


return Signal
