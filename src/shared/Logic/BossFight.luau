-- 보스 전투 상태: idle → fighting → defeated / failed(→ 대기 후 idle)
local BossFight = {}

export type Options = { maxHp: number, timeLimit: number, retryDelay: number, maxHitsPerSec: number }

-- 데미지는 몸 크기의 제곱에 비례
function BossFight.damageFor(scale: number): number
	return 5 * scale * scale
end

function BossFight.canReward(lastReward: number?, now: number, cooldown: number): boolean
	return lastReward == nil or now - lastReward >= cooldown
end

function BossFight.new(opt: Options)
	local hp = opt.maxHp
	local st = "idle"
	local startedAt = 0
	local retryAt = 0
	local damage: { [any]: number } = {}
	local recent: { [any]: { number } } = {}

	local self = {}

	local function update(now: number)
		if st == "fighting" then
			if hp <= 0 then
				st = "defeated"
			elseif now - startedAt >= opt.timeLimit then
				st = "failed"
				hp = opt.maxHp
				retryAt = now + opt.retryDelay
				table.clear(damage)
			end
		elseif st == "failed" and now >= retryAt then
			st = "idle"
		end
	end

	function self.state(now: number): string
		update(now)
		return st
	end

	function self.hp(): number
		return hp
	end

	function self.maxHp(): number
		return opt.maxHp
	end

	function self.timeLeft(now: number): number
		return if st == "fighting" then math.max(0, opt.timeLimit - (now - startedAt)) else 0
	end

	-- 받아들여졌으면 true
	function self.hit(who: any, amount: number, now: number): boolean
		update(now)
		if st == "idle" then
			st = "fighting"
			startedAt = now
			table.clear(damage)
		end
		if st ~= "fighting" or amount <= 0 then
			return false
		end
		local list = recent[who] or {}
		local kept = {}
		for _, t in list do
			if now - t < 1 then
				table.insert(kept, t)
			end
		end
		if #kept >= opt.maxHitsPerSec then
			recent[who] = kept
			return false
		end
		table.insert(kept, now)
		recent[who] = kept
		local dealt = math.min(amount, hp)
		hp -= dealt
		damage[who] = (damage[who] or 0) + dealt
		update(now)
		return true
	end

	-- 체력의 minShare 이상 때린 사람들
	function self.winners(minShare: number): { any }
		local out = {}
		for who, d in damage do
			if d >= opt.maxHp * minShare then
				table.insert(out, who)
			end
		end
		return out
	end

	function self.reset()
		hp = opt.maxHp
		st = "idle"
		table.clear(damage)
		table.clear(recent)
	end

	return self
end

return BossFight
