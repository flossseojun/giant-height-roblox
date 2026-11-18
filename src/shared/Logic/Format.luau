-- 화면에 보여 줄 키 글자
local Format = {}

local function commas(intStr: string): string
	local out = intStr
	while true do
		local n
		out, n = string.gsub(out, "^(%d+)(%d%d%d)", "%1,%2")
		if n == 0 then
			return out
		end
	end
end

local function trimNumber(x: number): string
	-- 소수 첫째 자리까지, 끝의 .0은 지움
	local s = string.format("%.1f", x)
	s = string.gsub(s, "%.0$", "")
	local int, frac = string.match(s, "^(%d+)(.*)$")
	return commas(int) .. frac
end

function Format.height(cm: number): string
	if cm >= 100000 then
		return trimNumber(math.floor(cm / 100000 * 10) / 10) .. "km"
	end
	return commas(tostring(math.floor(cm))) .. "cm"
end

function Format.gain(cm: number): string
	return "+" .. trimNumber(cm) .. "cm"
end

return Format
