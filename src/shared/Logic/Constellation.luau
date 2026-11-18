-- 별자리 따라 걷기: 별을 1번부터 순서대로 밟으면 완성 (한 사람당 하나씩 만들어 씀)
local Constellation = {}

function Constellation.new(timeLimit: number)
	local progress: { [string]: number } = {}
	local startedAt: { [string]: number } = {}
	local self = {}

	function self.progress(name: string): number
		return progress[name] or 0
	end

	-- 결과: "progress" | "complete" | "reset" | "same"
	function self.touch(name: string, index: number, total: number, now: number): string
		local p = progress[name] or 0
		if p > 0 and now - (startedAt[name] or now) > timeLimit then
			p = 0
			progress[name] = 0
			if index ~= 1 then
				return "reset"
			end
		end
		if index == p then
			return "same"
		end
		if index == 1 then
			progress[name] = 1
			startedAt[name] = now
			return if total == 1 then "complete" else "progress"
		end
		if index ~= p + 1 then
			progress[name] = 0
			return "reset"
		end
		progress[name] = index
		if index >= total then
			progress[name] = 0
			return "complete"
		end
		return "progress"
	end

	return self
end

return Constellation
