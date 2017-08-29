local base64 = require("levee.p.base64")


return {
	test_encode = function()
		local s = "fa-f3;fo,fi\nfum/"
		assert.equal(base64.encode(s), "ZmEtZjM7Zm8sZmkKZnVtLw==")
	end,
	test_decode = function()
		local s = "ZmEtZjM7Zm8sZmkKZnVtLw=="
		assert.equal(base64.decode(s), "fa-f3;fo,fi\nfum/")
	end,
}
