local ffi = require('ffi')
local C = ffi.C


return {
	test_core = function()
		print()
		print()
		print("---")


		local poller = require("levee.sys.poller")()

		poller:register_signal(C.SIGTERM)

		local pid = C.getpid()
		print("KILL", C.kill(pid, 15))

		local ev_out, n = poller:poll(0)
		print(n, ev_out)
		print(ev_out[0].ident)

		poller:unregister_signal(C.SIGTERM)
		local pid = C.getpid()
		print("KILL", C.kill(pid, 15))

		local ev_out, n = poller:poll(0)
		print(n, ev_out)

	end,
}
