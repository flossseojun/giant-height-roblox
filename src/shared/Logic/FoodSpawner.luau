-- 어떤 음식이 나올지 정하고, 한 음식은 한 명만 먹게 한다
local FoodSpawner = {}

export type Food = { id: string, name: string, gain: number, golden: boolean }

-- rollGolden, rollWhich: 0 이상 1 미만 난수
function FoodSpawner.pick(zone, rollGolden: number, rollWhich: number, goldenChance: number, goldenMult: number): Food
	if rollGolden < goldenChance then
		local best = 0
		for _, f in zone.foods do
			best = math.max(best, f.gain)
		end
		return { id = "golden_milk", name = "황금 우유", gain = best * goldenMult, golden = true }
	end
	local n = #zone.foods
	local i = math.clamp(math.floor(rollWhich * n) + 1, 1, n)
	local f = zone.foods[i]
	return { id = f.id, name = f.name, gain = f.gain, golden = false }
end

function FoodSpawner.newSlot()
	local taken = false
	return {
		claim = function(): boolean
			if taken then
				return false
			end
			taken = true
			return true
		end,
		reset = function()
			taken = false
		end,
	}
end

return FoodSpawner
