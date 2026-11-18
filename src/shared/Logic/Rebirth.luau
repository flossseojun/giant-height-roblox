-- 환생: 키를 처음으로 되돌리는 대신 영구 성장 배율
local Rebirth = {}

-- n번 환생한 사람이 다음 환생에 필요한 키
function Rebirth.requirement(rebirths: number, base: number): number
	return base * (rebirths + 1)
end

function Rebirth.canRebirth(height: number, rebirths: number, base: number): boolean
	return height >= Rebirth.requirement(rebirths, base)
end

function Rebirth.multiplier(rebirths: number, step: number): number
	return 1 + rebirths * step
end

return Rebirth
