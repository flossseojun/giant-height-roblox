-- 우유 비 일정 계산
local MilkRain = {}

-- elapsed: 서버 시작 후 지난 초
function MilkRain.phase(elapsed: number, interval: number, warn: number): "idle" | "warning" | "raining"
	if elapsed < interval - warn then
		return "idle"
	end
	local t = elapsed % interval
	if t >= interval - warn then
		return "warning"
	end
	if t < 1 then
		return "raining"
	end
	return "idle"
end

function MilkRain.dropGain(zone, mult: number): number
	local best = 0
	for _, f in zone.foods do
		best = math.max(best, f.gain)
	end
	return best * mult
end

return MilkRain
