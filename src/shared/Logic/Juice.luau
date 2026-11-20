-- 손맛 계산 (순수 함수): 키 돌파, 먹기 콤보, 부드럽게 커지는 단계
local Juice = {}

-- old < cm <= new 인 돌파 지점들 (오름차순). 줄어들면 없음.
function Juice.crossed(old: number, new: number, list: { any }): { any }
	local out = {}
	if new <= old then
		return out
	end
	for _, m in list do
		if old < m.cm and m.cm <= new then
			table.insert(out, m)
		end
	end
	return out
end

-- 창(window)초 안에 또 먹으면 콤보 +1, 아니면 1부터
function Juice.combo(lastAt: number?, count: number, now: number, window: number): number
	if lastAt ~= nil and now - lastAt <= window then
		return count + 1
	end
	return 1
end

-- 크기 변화가 minRatio 이상이면 n단계로 나눔, 아니면 바로
function Juice.scaleSteps(from: number, to: number, n: number, minRatio: number): { number }
	if from <= 0 or math.abs(to / from - 1) < minRatio then
		return { to }
	end
	local out = {}
	for i = 1, n do
		out[i] = if i == n then to else from + (to - from) * i / n
	end
	return out
end

return Juice
