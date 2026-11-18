-- 최종 성장 배율 = 펫 배율 × (하이파이브 중이면 2)
local Boost = {}

function Boost.multiplier(petMult: number, highFiveUntil: number, now: number): number
	local m = petMult
	if now < highFiveUntil then
		m *= 2
	end
	return m
end

return Boost
