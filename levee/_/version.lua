local lpeg = require('lpeg')
local P, R, S, Ct, Cg = lpeg.P, lpeg.R, lpeg.S, lpeg.Ct, lpeg.Cg

local num = (S("0123456789xX")^0)/tonumber
local id = (R("az","AZ","09")^0)/tostring
local pre = P("-") * Cg(id, "pre_release_name") * ("." * Cg(num, "pre_release_version"))^-1
local ver =
	Ct(P("v")^-1
	* Cg(num, "major")
		* ("." * Cg(num, "minor")
			* ("." * Cg(num, "patch")
				* pre^-1)^-1)^-1) * P(-1)


local Version_mt = {}
Version_mt.__index = Version_mt


local function make(t)
	if t.pre_release_name and not t.pre_release then
		t.pre_release = ("-%s.%s"):format(
			t.pre_release_name,
			t.pre_release_version or "x")
	end
	return setmetatable(t, Version_mt)
end


local function copy(v)
	return make({
		major = v.major,
		minor = v.minor,
		patch = v.patch,
		pre_release = v.pre_release,
		pre_release_name = v.pre_release_name,
		pre_release_version = v.pre_release_version
	})
end


local function parse(v)
	local t = ver:match(v)
	if t then return make(t) end
end


function Version_mt:is_compatible(v)
	if type(v) == "string" then
		v = parse(v)
	end
	if self.pre_release_name ~= v.pre_release_name then
		return false
	end
	for i,key in ipairs{"pre_release_version", "patch", "minor", "major"} do
		if v[key] and self[key] ~= v[key] then
			return false
		end
	end
	return true
end


function Version_mt:__eq(other)
	return self.major == other.major
		and self.minor == other.minor
		and self.patch == other.patch
		and self.pre_release_name == other.pre_release_name
		and self.pre_release_version == other.pre_release_version
end


function Version_mt:__tostring()
	return ("v%s.%s.%s%s"):format(
		self.major or "x",
		self.minor or "x",
		self.patch or "x",
		self.pre_release or "")
end


return function(v)
	local out
	if type(v) == "table" then
	elseif type(v) == "string" then
		return parse(v)
	end
end
