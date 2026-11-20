local H = require("./harness")
local Config = require("../src/shared/Config")
local PetProgress = require("../src/shared/Logic/PetProgress")
local PetData = require("../src/shared/Logic/PetData")
local describe, it, expect = H.describe, H.it, H.expect
PetProgress.setConfig(Config.PET)
PetData.setConfig(Config.PET)

describe("PetProgress", function()
	it("xp curve", function()
		expect(PetProgress.xpToNext(1)).toBe(10)
		expect(PetProgress.xpToNext(4)).toBe(80)
	end)
	it("addXp levels up and carries over", function()
		local l, x, up = PetProgress.addXp(1, 5, 20)
		expect(l).toBe(2)
		expect(x).toBe(15)
		expect(up).toBe(1)
		local l2, x2 = PetProgress.addXp(50, 0, 99999)
		expect(l2).toBe(50)
		expect(x2).toBe(0)
	end)
	it("stage", function()
		expect(PetProgress.stage(14)).toBe(1)
		expect(PetProgress.stage(15)).toBe(2)
		expect(PetProgress.stage(35)).toBe(3)
	end)
	it("stat", function()
		expect(PetProgress.stat(10, 1)).toBeCloseTo(10)
		expect(PetProgress.stat(10, 15)).toBeCloseTo(10 * (1 + 0.12 * 14) * 1.5)
	end)
	it("team bonus is best, not product", function()
		local S = Config.PET_SPECIES
		local m, r = PetProgress.teamBonus({ { species = S.cat, level = 1 }, { species = S.otter, level = 10 } })
		expect(m).toBeCloseTo(1.25 + 0.10)
		expect(r).toBeCloseTo(14 * 1.2)
		local m0, r0 = PetProgress.teamBonus({})
		expect(m0).toBe(1)
		expect(r0).toBe(0)
	end)
end)

describe("PET_SPECIES", function()
	it("has 13 species with valid fields", function()
		local n = 0
		for id, s in Config.PET_SPECIES do
			n += 1
			expect(s.id).toBe(id)
			expect(#s.stages).toBe(3)
			expect(s.skill.cooldown >= 12 and s.skill.cooldown <= 20).toBe(true)
			if s.how == "tame" then
				expect(s.tameChance == 0.08 or s.tameChance == 0.03).toBe(true)
				expect(s.monster ~= nil).toBe(true)
			end
		end
		expect(n).toBe(13)
	end)
end)

describe("PetData", function()
	local S = Config.PET_SPECIES
	it("migrates old save", function()
		local d = PetData.migrate({ pet = "otter" }, S, 2000)
		expect(#d.owned).toBe(2)
		local t = PetData.teamEntries(d)
		expect(#t).toBe(1)
		expect(t[1].kind).toBe("otter")
	end)
	it("keeps valid new save, drops broken entries", function()
		local d = PetData.migrate({
			pets = {
				owned = { { uid = 1, kind = "duck", level = 3, xp = 2 }, { uid = 2, kind = "nope", level = 1, xp = 0 } },
				team = { 1, 2 },
				nextId = 3,
			},
		}, S, 0)
		expect(#d.owned).toBe(2) -- duck + 키 0에서 열리는 cat
		expect(PetData.find(d, 2)).toBe(nil)
		expect(#d.team).toBe(1)
	end)
	it("setTeam validates", function()
		local d = PetData.migrate({}, S, 200000)
		local a, b, c = d.owned[1].uid, d.owned[2].uid, d.owned[3].uid
		expect(PetData.setTeam(d, { a, a })).toBe(false)
		expect(PetData.setTeam(d, { a, 999 })).toBe(false)
		expect(PetData.setTeam(d, "x")).toBe(false)
		local x = PetData.add(d, "duck") :: number
		expect(PetData.setTeam(d, { a, b, c, x })).toBe(false)
		expect(PetData.setTeam(d, { c, a })).toBe(true)
		expect(d.team[1]).toBe(c)
	end)
	it("add respects cap", function()
		local d = PetData.migrate({}, S, 0)
		for _ = 1, 40 do
			PetData.add(d, "pigeon")
		end
		expect(#d.owned).toBe(30)
		expect(PetData.add(d, "pigeon")).toBe(nil)
		expect(PetData.add(d, "nope")).toBe(nil)
	end)
	it("unlockByHeight adds once", function()
		local d = PetData.migrate({}, S, 0)
		expect(#PetData.unlockByHeight(d, S, 1000)).toBe(1)
		expect(#PetData.unlockByHeight(d, S, 1000)).toBe(0)
	end)
end)

return nil
