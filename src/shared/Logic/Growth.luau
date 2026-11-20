-- 키(cm) → 몸 크기, 이동 능력 계산 (로블록스 API 안 씀)
local Growth = {}

function Growth.heightToScale(height: number, k: number, maxScale: number): number
	if height ~= height or height <= 150 then
		return 1
	end
	local s = 1 + k * math.log10(height / 150)
	if s ~= s or s > maxScale then
		return maxScale
	end
	return s
end

function Growth.shouldRescale(oldScale: number, newScale: number): boolean
	return math.abs(newScale - oldScale) >= 0.02
end

function Growth.moveStats(scale: number): { walkSpeed: number, jumpPower: number, maxZoom: number, minZoom: number }
	local r = math.sqrt(scale)
	return {
		walkSpeed = 16 * r,
		jumpPower = 50 * r,
		maxZoom = 30 * scale,
		-- 거인이 되면 카메라가 몸 안에 들어가지 않도록 최소 거리도 키움
		minZoom = if scale >= 2 then 4 * scale else 0.5,
	}
end

return Growth
