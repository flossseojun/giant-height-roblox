-- 철봉 연타 판정: 최근 1초 동안 몇 번 눌렀나
local BarMash = {}

-- startTime이 있으면 매달린 직후 1초는 안 떨어짐
function BarMash.new(minRate: number, maxRate: number, startTime: number?)
	local presses: { number } = {}
	local graceUntil = (startTime or -math.huge) + 1

	local function prune(t: number)
		local i = 1
		while i <= #presses and presses[i] <= t - 1 do
			i += 1
		end
		if i > 1 then
			local kept = {}
			for j = i, #presses do
				table.insert(kept, presses[j])
			end
			presses = kept
		end
	end

	local self = {}

	function self.count(t: number): number
		prune(t)
		return #presses
	end

	function self.press(t: number)
		prune(t)
		if #presses < maxRate then
			table.insert(presses, t)
		end
	end

	function self.tick(t: number): "hold" | "fall"
		if t < graceUntil then
			return "hold"
		end
		return if self.count(t) >= minRate then "hold" else "fall"
	end

	return self
end

return BarMash
