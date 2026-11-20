-- 펫 레벨·진화·능력치·팀 보너스 계산 (순수 함수)
-- 숫자는 Config.PET: 시작할 때 PetProgress.setConfig(Config.PET) 한 번 호출
local PetProgress = {}
local P: any = nil

function PetProgress.setConfig(cfg: any)
	P = cfg
end

local function cfg(): any
	assert(P, "PetProgress.setConfig(Config.PET)를 먼저 불러야 해요")
	return P
end

function PetProgress.xpToNext(level: number): number
	return math.floor(10 * level ^ 1.5 + 0.5)
end

-- → 새 레벨, 남은 xp, 오른 레벨 수
function PetProgress.addXp(level: number, xp: number, gain: number): (number, number, number)
	local up = 0
	xp += math.max(0, gain)
	while level < cfg().maxLevel and xp >= PetProgress.xpToNext(level) do
		xp -= PetProgress.xpToNext(level)
		level += 1
		up += 1
	end
	if level >= cfg().maxLevel then
		level, xp = cfg().maxLevel, 0
	end
	return level, xp, up
end

function PetProgress.stage(level: number): number
	local s = 1
	for _, lv in cfg().evoLevels do
		if level >= lv then
			s += 1
		end
	end
	return s
end

function PetProgress.stat(base: number, level: number): number
	return base * (1 + cfg().statPerLevel * (level - 1)) * cfg().evoMult[PetProgress.stage(level)]
end

-- 팀에서 가장 좋은 펫 기준 (곱하지 않음) → 성장 배율, 줍기 반경
function PetProgress.teamBonus(members: { { species: any, level: number } }): (number, number)
	local mult, radius = 1, 0
	for _, m in members do
		mult = math.max(mult, m.species.mult + 0.01 * m.level)
		radius = math.max(radius, m.species.radius * (1 + 0.02 * m.level))
	end
	return mult, radius
end

return PetProgress
