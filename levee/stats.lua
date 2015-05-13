local Stats = {}
Stats.__index = Stats

function Stats:add(val)
	table.insert(self.vals, val)
end

function Stats:clear()
	self.vals = {}
	self.valn = nil
end

function Stats:stats()
	local vals = self.vals

	if #vals == self.valn and self.cache ~= nil then
		return self.cache
	end

	table.sort(vals)

	local n = #vals
	local sum = 0.0
	local sq_sum = 0.0
	local pow = math.pow
	for i=1,n do
		sum = sum + vals[i]
		sq_sum = sq_sum + pow(vals[i], 2)
	end

	local mean = sum / n

	local median
	if math.fmod(n, 2) == 0 then
		median = (vals[n/2] + vals[(n/2)+1]) / 2
	else
		median = vals[math.ceil(n/2)]
	end

	local variance = sq_sum / n - pow(mean, 2)
	local stdev = math.sqrt(variance)

	local result = {
		sum = sum,
		count = n,
		mean = mean,
		median = median,
		variance = variance,
		stdev = stdev,
		min = vals[1],
		max = vals[n]
	}

	self.cache = result
	self.valn = n
	return result
end

function Stats:sum()    return self:stats().sum    end
function Stats:mean()   return self:stats().mean   end
function Stats:median() return self:stats().median end
function Stats:stdev()  return self:stats().stdev  end
function Stats:min()    return self:stats().min    end
function Stats:max()    return self:stats().max    end

function Stats:zscore(val)
	local stats = self:stats()
	return (val - stats.mean) / stats.stdev
end

return function()
	return setmetatable({vals={}}, Stats)
end
