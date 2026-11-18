-- 하이파이브: A가 제안 → B가 받으면 둘 다 부스트. 같은 짝은 쿨다운.
local HighFive = {}

export type Options = { offerTime: number, cooldown: number, duration: number }

function HighFive.new(opt: Options)
	local offers: { [string]: number } = {} -- "from:to" → 제안 시각
	local lastPair: { [string]: number } = {}

	local function pairKey(a, b): string
		local x, y = tostring(a), tostring(b)
		return if x < y then x .. "|" .. y else y .. "|" .. x
	end

	local self = {}

	function self.request(from: any, to: any, now: number): boolean
		if from == to then
			return false
		end
		local last = lastPair[pairKey(from, to)]
		if last and now - last < opt.cooldown then
			return false
		end
		offers[tostring(from) .. ":" .. tostring(to)] = now
		return true
	end

	-- 받는 사람(to)이 보낸 사람(from)의 제안을 받음 → (성공, 부스트 끝나는 시각)
	function self.accept(to: any, from: any, now: number): (boolean, number)
		local key = tostring(from) .. ":" .. tostring(to)
		local t = offers[key]
		if not t or now - t > opt.offerTime then
			return false, 0
		end
		offers[key] = nil
		lastPair[pairKey(from, to)] = now
		return true, now + opt.duration
	end

	return self
end

return HighFive
