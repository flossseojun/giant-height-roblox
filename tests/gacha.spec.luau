local H = require("./harness")
local Config = require("../src/shared/Config")
local Gacha = require("../src/shared/Logic/Gacha")
local describe, it, expect = H.describe, H.it, H.expect
Gacha.setConfig(Config.COSMETICS)

describe("Gacha", function()
	it("15 items, 2/2/1 per kind", function()
		local cnt = {}
		for _, it_ in Config.COSMETICS.items do
			local k = it_.kind .. ":" .. it_.rarity
			cnt[k] = (cnt[k] or 0) + 1
		end
		for _, kind in { "wing", "aura", "trail" } do
			expect(cnt[kind .. ":common"]).toBe(2)
			expect(cnt[kind .. ":rare"]).toBe(2)
			expect(cnt[kind .. ":legendary"]).toBe(1)
		end
	end)
	it("rarity boundaries", function()
		expect(Gacha.rarity(0.69)).toBe("common")
		expect(Gacha.rarity(0.70)).toBe("rare")
		expect(Gacha.rarity(0.949)).toBe("rare")
		expect(Gacha.rarity(0.95)).toBe("legendary")
	end)
	it("open adds new, refunds dup", function()
		local s = Gacha.newState()
		local a = Gacha.open(s, "wing", 0.1, 0.1) :: any
		expect(a.rarity).toBe("common")
		expect(a.dup).toBe(false)
		expect(s.owned[a.id]).toBe(true)
		local b = Gacha.open(s, "wing", 0.1, 0.1) :: any
		expect(b.id).toBe(a.id)
		expect(b.dup).toBe(true)
		expect(b.refund).toBe(50)
		expect(Gacha.open(s, "hat", 0.1, 0.1)).toBe(nil)
	end)
	it("pity: 30th is legendary, resets", function()
		local s = Gacha.newState()
		for _ = 1, 29 do
			expect((Gacha.open(s, "aura", 0.1, 0.5) :: any).rarity).toBe("common")
		end
		expect((Gacha.open(s, "aura", 0.1, 0.5) :: any).rarity).toBe("legendary")
		expect(s.pity.aura).toBe(0)
		expect(s.pity.wing).toBe(0)
	end)
	it("equip validates", function()
		local s = Gacha.newState()
		local a = Gacha.open(s, "trail", 0.1, 0.1) :: any
		expect(Gacha.equip(s, "trail", a.id)).toBe(true)
		expect(s.equipped.trail).toBe(a.id)
		expect(Gacha.equip(s, "wing", a.id)).toBe(false)
		expect(Gacha.equip(s, "trail", "nope")).toBe(false)
		expect(Gacha.equip(s, "hat", nil)).toBe(false)
		expect(Gacha.equip(s, "trail", nil)).toBe(true)
		expect(s.equipped.trail).toBe(nil)
	end)
	it("clean drops junk", function()
		local first = Config.COSMETICS.items[1].id
		local s = Gacha.clean({ owned = { nope = true, [first] = true }, equipped = { wing = "nope" }, pity = { wing = -3, aura = "x" } })
		expect(s.owned.nope).toBe(nil)
		expect(s.owned[first]).toBe(true)
		expect(s.equipped.wing).toBe(nil)
		expect(s.pity.wing).toBe(0)
		expect(s.pity.aura).toBe(0)
		expect(Gacha.clean("garbage").pity.trail).toBe(0)
	end)
end)

return nil
