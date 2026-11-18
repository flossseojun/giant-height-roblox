-- 늦게 온 친구 따라잡기: 서버 1등보다 훨씬 작으면 성장 보너스
local CatchUp = {}

function CatchUp.multiplier(myHeight: number, topHeight: number): number
	if topHeight <= 0 or myHeight >= topHeight then
		return 1
	end
	local ratio = myHeight / topHeight
	if ratio < 0.01 then
		return 3
	elseif ratio < 0.1 then
		return 2
	end
	return 1
end

return CatchUp
