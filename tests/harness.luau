-- 아주 작은 테스트 도구: describe / it / expect
local H = { passed = 0, failed = 0, failures = {} }
local prefix = ""

function H.describe(name: string, fn: () -> ())
	local old = prefix
	prefix = prefix .. name .. " > "
	fn()
	prefix = old
end

function H.it(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		H.passed += 1
	else
		H.failed += 1
		table.insert(H.failures, prefix .. name .. "\n    " .. tostring(err))
	end
end

local function fmt(v)
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function H.expect(actual)
	local m = {}
	function m.toBe(expected)
		if actual ~= expected then
			error("expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
		end
	end
	function m.toBeCloseTo(expected: number, eps: number?)
		local e = eps or 1e-6
		if type(actual) ~= "number" or math.abs(actual - expected) > e then
			error("expected ~" .. fmt(expected) .. ", got " .. fmt(actual), 2)
		end
	end
	return m
end

return H
