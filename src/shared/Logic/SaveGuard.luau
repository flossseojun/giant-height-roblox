-- 불러오기에 실패한 플레이어는 저장하지 않게 막는다 (기본값으로 덮어쓰기 방지)
local SaveGuard = {}

function SaveGuard.new()
	local loadedOk = false
	return {
		markLoaded = function(ok: boolean)
			loadedOk = ok
		end,
		canSave = function(): boolean
			return loadedOk
		end,
	}
end

-- 저장돼 있던 값이 이상하면 시작 키로
function SaveGuard.cleanHeight(data: any, startHeight: number): number
	if type(data) ~= "table" then
		return startHeight
	end
	local h = data.height
	if type(h) ~= "number" or h ~= h or h == math.huge or h < startHeight then
		return startHeight
	end
	return h
end

return SaveGuard
