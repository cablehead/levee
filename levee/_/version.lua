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


local function make_pre_release(t)
	return ("-%s.%s"):format(
		t.pre_release_name,
		t.pre_release_version or "x")
end

local function make(t)
	if t.pre_release_name and not t.pre_release then
		t.pre_release = make_pre_release(t)
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
		if not v then return false end
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


function Version_mt:_bump_pre_release(val)
	if not self.pre_release_name then
		self.patch = self.patch + 1
		self.pre_release_name = "alpha"
		self.pre_release_version = 1 or val
	else
		self.pre_release_version = val or self.pre_release_version + 1
	end
	self.pre_release = make_pre_release(self)
end


function Version_mt:_bump_patch(val)
	self.patch = val or self.patch + 1
	self.pre_release = ""
	self.pre_release_name = nil
	self.pre_release_version = nil
end


function Version_mt:_bump_minor(val)
	self:_bump_patch(0)
	self.minor = val or self.minor + 1
end


function Version_mt:_bump_major(val)
	self:_bump_minor(0)
	self.major = val or self.major + 1
end


function Version_mt:bump(field, val)
	local new = copy(self)
	if not field then
		for i,key in ipairs{"pre_release", "patch", "minor", "major"} do
			if new[key] then
				field = key
				break
			end
		end
	end
	new["_bump_"..field](new, val)
	return new
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
