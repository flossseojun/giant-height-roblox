-- 주간 순위: 한국 시간 월요일 0시에 새 주가 시작
local Week = {}

-- 1970-01-05(월) 00:00 KST부터 몇 번째 주인지
function Week.key(unixTime: number): number
	local kst = math.floor(unixTime) + 9 * 3600
	local mondayEpoch = 4 * 86400 -- 1970-01-05가 월요일
	return math.floor((kst - mondayEpoch) / (7 * 86400))
end

-- 이번 주 성장량. extra 테이블(저장됨)에 주 시작 키를 기록한다
function Week.gain(extra: { [string]: any }, height: number, key: number): number
	if extra.weekKey ~= key or type(extra.weekStart) ~= "number" then
		extra.weekKey = key
		extra.weekStart = height
	end
	return math.max(0, height - extra.weekStart)
end

-- 이번 주에 큰 만큼을 쌓아 둔다 (환생으로 키가 줄어도 주간 기록은 그대로)
function Week.add(extra: { [string]: any }, amount: number, key: number): number
	if extra.weekKey ~= key or type(extra.weekGain) ~= "number" then
		extra.weekKey = key
		extra.weekGain = 0
	end
	extra.weekGain += amount
	return extra.weekGain
end

function Week.total(extra: { [string]: any }, key: number): number
	if extra.weekKey ~= key or type(extra.weekGain) ~= "number" then
		return 0
	end
	return extra.weekGain
end

return Week
