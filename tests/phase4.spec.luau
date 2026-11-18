local H = require("./harness")
local Config = require("../src/shared/Config")
local Rebirth = require("../src/shared/Logic/Rebirth")
local Quests = require("../src/shared/Logic/Quests")
local CatchUp = require("../src/shared/Logic/CatchUp")
local Week = require("../src/shared/Logic/Week")
local describe, it, expect = H.describe, H.it, H.expect

describe("Rebirth", function()
	it("requirement grows each time", function()
		expect(Rebirth.requirement(0, 115700)).toBe(115700)
		expect(Rebirth.requirement(1, 115700)).toBe(231400)
		expect(Rebirth.requirement(2, 115700)).toBe(347100)
	end)
	it("canRebirth", function()
		expect(Rebirth.canRebirth(115699, 0, 115700)).toBe(false)
		expect(Rebirth.canRebirth(115700, 0, 115700)).toBe(true)
		expect(Rebirth.canRebirth(200000, 1, 115700)).toBe(false)
	end)
	it("multiplier", function()
		expect(Rebirth.multiplier(0, 0.5)).toBeCloseTo(1)
		expect(Rebirth.multiplier(3, 0.5)).toBeCloseTo(2.5)
	end)
end)

describe("CatchUp", function()
	it("bonus when far behind the top", function()
		expect(CatchUp.multiplier(5000, 10000)).toBe(1)
		expect(CatchUp.multiplier(999, 10000)).toBe(2)
		expect(CatchUp.multiplier(99, 10000)).toBe(3)
		expect(CatchUp.multiplier(150, 150)).toBe(1) -- 나 혼자면 없음
		expect(CatchUp.multiplier(150, 0)).toBe(1)
	end)
end)

describe("Quests", function()
	local pool = Config.QUESTS.pool
	it("same 3 distinct quests for everyone on a day", function()
		local a = Quests.forDay(20000, pool, 3)
		local b = Quests.forDay(20000, pool, 3)
		expect(#a).toBe(3)
		for i = 1, 3 do
			expect(a[i].kind).toBe(b[i].kind)
		end
		expect(a[1].kind ~= a[2].kind and a[2].kind ~= a[3].kind and a[1].kind ~= a[3].kind).toBe(true)
	end)
	it("different days usually differ", function()
		local diff = 0
		for d = 20000, 20009 do
			local x, y = Quests.forDay(d, pool, 3), Quests.forDay(d + 1, pool, 3)
			if x[1].kind ~= y[1].kind or x[2].kind ~= y[2].kind or x[3].kind ~= y[3].kind then
				diff += 1
			end
		end
		expect(diff >= 8).toBe(true)
	end)
	it("record progress, complete once, new day resets", function()
		local list = { { kind = "hoop", count = 2, name = "골 2번" }, { kind = "food", count = 1, name = "음식" } }
		local state = {}
		expect(#Quests.record(state, list, 5, "hoop", 1)).toBe(0)
		local done = Quests.record(state, list, 5, "hoop", 1)
		expect(#done).toBe(1)
		expect(done[1]).toBe(1)
		expect(#Quests.record(state, list, 5, "hoop", 1)).toBe(0) -- 이미 완료
		expect(Quests.allDone(state, list)).toBe(false)
		Quests.record(state, list, 5, "food", 1)
		expect(Quests.allDone(state, list)).toBe(true)
		Quests.record(state, list, 6, "food", 0)
		expect(state.progress[1]).toBe(0)
	end)
	it("food kind counts any food id", function()
		expect(Quests.kindOf("hotteok")).toBe("food")
		expect(Quests.kindOf("golden_milk")).toBe("golden_milk")
		expect(Quests.kindOf("rainmilk")).toBe("rainmilk")
		expect(Quests.kindOf("hoop")).toBe("hoop")
	end)
end)

describe("Week (accumulated gains)", function()
	it("adds within a week, resets next week", function()
		local e = {}
		expect(Week.add(e, 100, 7)).toBe(100)
		expect(Week.add(e, 50, 7)).toBe(150)
		expect(Week.add(e, 10, 8)).toBe(10)
		expect(Week.total(e, 8)).toBe(10)
		expect(Week.total(e, 9)).toBe(0)
	end)
end)

return nil
