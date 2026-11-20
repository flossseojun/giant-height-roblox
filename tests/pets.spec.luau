local H = require("./harness")
local Config = require("../src/shared/Config")
local PetProgress = require("../src/shared/Logic/PetProgress")
local describe, it, expect = H.describe, H.it, H.expect
PetProgress.setConfig(Config.PET)

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

return nil
