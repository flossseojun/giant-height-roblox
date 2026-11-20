-- 건물 부수기 계산 (순수 함수). 숫자는 Config.SMASH: 시작할 때 Smash.setConfig(Config.SMASH)
local Smash = {}
local C: any = nil

function Smash.setConfig(cfg: any)
	C = cfg
end

local function cfg(): any
	assert(C, "Smash.setConfig(Config.SMASH)를 먼저 불러야 해요")
	return C
end

function Smash.heightCm(floors: number): number
	return floors * cfg().cmPerFloor
end

-- 착지 지점(feet)에서 닿는 건물 → (부술 id들: 가까운 순 최대 maxPerStomp, 키가 모자란 id들)
function Smash.targets(buildings: { any }, feet: any, scale: number, playerHeight: number, now: number): ({ any }, { any })
	local can, tall = {}, {}
	for _, b in buildings do
		if not (b.brokenUntil and now < b.brokenUntil) then
			local dx, dz = b.x - feet.X, b.z - feet.Z
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= b.radius + 3 * scale then
				if b.heightCm < playerHeight then
					table.insert(can, { id = b.id, d = d })
				else
					table.insert(tall, b.id)
				end
			end
		end
	end
	table.sort(can, function(a, b)
		return a.d < b.d
	end)
	local out = {}
	for i = 1, math.min(#can, cfg().maxPerStomp) do
		out[i] = can[i].id
	end
	return out, tall
end

function Smash.reward(bestGain: number, floors: number): number
	return bestGain * floors * cfg().rewardPerFloor
end

-- 복구 자리에 아무도 없어야 다시 세움
function Smash.canRestore(b: any, players: { any }): boolean
	for _, p in players do
		local dx, dz = p.X - b.x, p.Z - b.z
		if math.sqrt(dx * dx + dz * dz) <= b.radius then
			return false
		end
	end
	return true
end

return Smash
