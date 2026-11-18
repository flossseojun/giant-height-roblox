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

function Growth.moveStats(scale: number): { walkSpeed: number, jumpPower: number, maxZoom: number }
	local r = math.sqrt(scale)
	return {
		walkSpeed = 16 * r,
		jumpPower = 50 * r,
		maxZoom = 30 * scale,
	}
end

return Growth
