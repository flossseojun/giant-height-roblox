local H = require("./harness")
local Config = require("../src/shared/Config")
local PetProgress = require("../src/shared/Logic/PetProgress")
local PetData = require("../src/shared/Logic/PetData")
local MonsterCombat = require("../src/shared/Logic/MonsterCombat")
local BossFight = require("../src/shared/Logic/BossFight")
local describe, it, expect = H.describe, H.it, H.expect
PetProgress.setConfig(Config.PET)
PetData.setConfig(Config.PET)
MonsterCombat.setConfig(Config.PET)

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

local function v(x, z)
	return { X = x, Y = 0, Z = z }
end

describe("MonsterCombat", function()
	local M = {
		{ id = 1, pos = v(5, 0), hp = 10 },
		{ id = 2, pos = v(20, 0), hp = 10 },
		{ id = 3, pos = v(3, 0), hp = 0 },
	}
	local O = v(0, 0)
	it("pickTarget nearest alive, honors focus within 2x", function()
		expect(MonsterCombat.pickTarget(M, O, 14, nil)).toBe(1)
		expect(MonsterCombat.pickTarget(M, O, 14, 2)).toBe(2)
		expect(MonsterCombat.pickTarget(M, O, 8, 2)).toBe(1)
		expect(MonsterCombat.pickTarget(M, O, 14, 3)).toBe(1)
		expect(MonsterCombat.pickTarget({}, O, 14, nil)).toBe(nil)
	end)
	it("faint and revive", function()
		local s = MonsterCombat.newPetState(10)
		expect(MonsterCombat.damagePet(s, 4, 0)).toBe(false)
		expect(MonsterCombat.damagePet(s, 9, 1)).toBe(true)
		expect(MonsterCombat.alive(s)).toBe(false)
		expect(MonsterCombat.damagePet(s, 9, 2)).toBe(false) -- 이미 기절
		expect(MonsterCombat.tickRevive(s, 10)).toBe(false)
		expect(MonsterCombat.tickRevive(s, 11)).toBe(true)
		expect(s.hp).toBe(10)
	end)
	it("skills", function()
		local d = MonsterCombat.skillEffect("burst", 3, 1, M, O)
		expect(d[1]).toBe(15)
		local dn = MonsterCombat.skillEffect("burst", 3, 99, M, O)
		expect(next(dn)).toBe(nil)
		local a = MonsterCombat.skillEffect("aoe", 3, nil, M, O)
		expect(a[1]).toBe(6)
		expect(a[2]).toBe(nil)
		expect(a[3]).toBe(nil)
		local _, heal = MonsterCombat.skillEffect("heal", 3, nil, M, O)
		expect(heal).toBeCloseTo(0.4)
		expect(MonsterCombat.skillReady(nil, 12, 0)).toBe(true)
		expect(MonsterCombat.skillReady(5, 12, 10)).toBe(false)
		expect(MonsterCombat.skillReady(5, 12, 17)).toBe(true)
	end)
	it("stomp radius scales", function()
		local hit = MonsterCombat.stomp(M, O, 2, BossFight.damageFor(2))
		expect(hit[1]).toBe(BossFight.damageFor(2))
		expect(hit[2]).toBe(nil)
		expect(hit[3]).toBe(nil)
	end)
	it("monsterStats", function()
		local hp, atk, xp = MonsterCombat.monsterStats(Config.PET_SPECIES.pigeon, 4)
		expect(hp).toBe(120)
		expect(atk).toBe(8)
		expect(xp).toBe(5)
	end)
	it("tameRoll", function()
		expect(MonsterCombat.tameRoll(0.08, 0.079)).toBe(true)
		expect(MonsterCombat.tameRoll(0.08, 0.08)).toBe(false)
	end)
end)

describe("Boss pets", function()
	it("every boss gives a boss-type species", function()
		for _, b in Config.BOSSES do
			local sp = Config.PET_SPECIES[b.pet]
			expect(sp ~= nil).toBe(true)
			expect(sp.how).toBe("boss")
			expect(sp.zone).toBe(b.zone)
		end
	end)
end)

return nil
