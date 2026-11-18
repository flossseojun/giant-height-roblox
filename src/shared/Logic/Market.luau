-- 물맑은시장 장날: 매달 3·8로 끝나는 날 (3, 8, 13, 18, 23, 28일)
local Market = {}

function Market.isMarketDay(day: number): boolean
	return day % 5 == 3
end

-- 유닉스 시각 → 한국 날짜의 "일"
function Market.kstDay(unixTime: number): number
	return (os.date("!*t", math.floor(unixTime) + 9 * 3600) :: any).day
end

return Market
