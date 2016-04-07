return {
	test_core = function()
		local ffi = require("ffi")
		local levee = require("levee")
		local _ = levee._
		print()
		print()
		local state = C.levee_dialer_init()
		print(state.rc)
		print(state.io[0])
		print(state.io[1])
		print()

		local req = ffi.new("struct LeveeDialerRequest")
		local res = ffi.new("struct LeveeDialerResponse")

		local r, w = _.pipe()

		local function write(node, service)
			req.node_len = #node
			req.service_len = #service
			req.socktype = C.SOCK_STREAM
			req.family = C.AF_INET
			req.no = w

			print(_.write(state.io[1], req, ffi.sizeof(req)))
			print(_.write(state.io[1], node))
			print(_.write(state.io[1], service))
			print(_.read(r, res, ffi.sizeof(res)))
			print(res.no)
		end

		write("localhost", "8000")

	end,
}
