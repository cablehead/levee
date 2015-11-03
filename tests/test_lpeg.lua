local lpeg = require("lpeg")

return {
	test_sum = function()

		-- matches a numeral and captures its numerical value
		local number = lpeg.R"09"^1 / tonumber

		-- matches a list of numbers, capturing their values
		local list = number * ("," * number)^0

		-- auxiliary function to add two numbers
		local function add(acc, newvalue) return acc + newvalue end

		-- folds the list of numbers adding them
		local sum = lpeg.Cf(list, add)

		assert.equal(sum:match("10,30,43"), 83)
	end,
}
