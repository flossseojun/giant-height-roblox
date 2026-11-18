-- 구역 조건 계산
local Zones = {}

function Zones.canEnter(height: number, zone): boolean
	return height >= zone.minHeight
end

function Zones.highestUnlocked(height: number, zones): number
	local best = 1
	for i, zone in zones do
		if height >= zone.minHeight then
			best = math.max(best, i)
		end
	end
	return best
end

function Zones.bestGain(zone): number
	local m = 0
	for _, f in zone.foods do
		m = math.max(m, f.gain)
	end
	return m
end

return Zones
