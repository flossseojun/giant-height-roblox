# 코인 + 꾸미기 뽑기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 활동으로 코인을 벌고, 종류별 랜덤 상자(날개·오라·발자국)를 열어 꾸미기를 모으고 착용하면 모두의 화면에 보이게 한다.

**Architecture:** 뽑기·천장·환급·저장 정리는 순수 모듈 `Logic/Gacha`(luau 테스트). 서버는 `CoinService`(코인 저장·지급·기존 서비스 연결)와 `ShopService`(상자 열기·착용·속성 공개). 클라이언트는 `ShopClient`(코인 표시·상점 창·여는 연출)와 `Cosmetics`(모든 플레이어의 날개·오라·발자국 그리기).

**Tech Stack:** Luau, Rojo 7.6, luau CLI 테스트, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-20-coins-cosmetics-gacha-design.md`

## Global Constraints

- 확률 일반 0.70 / 희귀 0.25 / 전설 0.05 (`r < 0.70` 일반, `r < 0.95` 희귀, 나머지 전설). 천장 30(연속 비전설 29번 뒤 다음은 전설), 전설이면 천장 0으로.
- 상자 100코인, 중복 환급 50. 종류별 상자: `wing`, `aura`, `trail`.
- 아이템 15개(종류마다 일반 2·희귀 2·전설 1), 스펙 표의 이름 그대로.
- 코인: 몬스터 마지막 타격 `2 × 구역`, 건물 부수기 `층수 × 1`, 보스 보상 받을 때 `50 × 구역`, 미션 하나 `20`, 세 개 다 `50`.
- 뽑기는 서버가 굴린다. 처음 얻은 꾸미기는 그 종류가 빈칸일 때만 자동 착용. 전설은 `Remotes.notifyAll`.
- 발자국: 보폭 `2 × scale`, 3초 뒤 삭제, 플레이어당 최대 20개.
- 저장: `extra.coins`, `extra.cosmetics = {owned={[id]=true}, equipped={wing?,aura?,trail?}, pity={wing,aura,trail}}`.
- Logic 모듈은 Config를 require하지 않음 → `Gacha.setConfig(Config.COSMETICS)`.
- 커밋 끝에 Co-Authored-By/Claude-Session 줄.

## Review Focus

- 코인이 99일 때 상자 열기 요청을 연타 → 한 번도 안 열리고 코인 음수 없음. 100일 때 연타 → 정확히 한 번.
- 클라이언트가 없는 종류("hat"), 보유하지 않은 id, 다른 종류의 id로 착용 요청 → 거절, 상태 불변.
- 저장에 사라진 아이템 id·문자열 코인·음수 코인 → 정리되어 0 이상 정수.
- 발자국: 거인(scale 12)이 빨리 달릴 때도 동시 20개를 넘지 않음.
- 플레이어가 나간 뒤 도착한 코인 지급(몬스터 처치 직후 퇴장 등) → 에러 없음.

---

### Task 1: Gacha — 아이템·확률·천장·환급·저장 정리

**Files:** Create `src/shared/Logic/Gacha.luau`; Modify `src/shared/Config.luau`; Test `tests/gacha.spec.luau` (run.luau에 추가)

**Interfaces:**
- Produces:
  - `Config.COINS = { monster = 2, smashPerFloor = 1, boss = 50, quest = 20, questAll = 50 }`
  - `Config.COSMETICS = { price = 100, refund = 50, pity = 30, rates = { common = 0.70, rare = 0.25, legendary = 0.05 }, kinds = { "wing", "aura", "trail" }, items = { {id, kind, rarity, name, color: Color3?, color2: Color3?} ×15 } }` (Color3는 `Color3 and Color3.fromRGB(...)` 가드 — luau CLI 호환, 기존 Config 방식)
  - `Gacha.setConfig(cfg)`
  - `Gacha.rarity(r: number): string`
  - `Gacha.newState(): State` (`{owned={}, equipped={}, pity={wing=0,aura=0,trail=0}}`)
  - `Gacha.clean(saved: any): State`
  - `Gacha.open(s: State, kind: string, r1: number, r2: number): {id: string, rarity: string, dup: boolean, refund: number}?` — 잘못된 kind면 nil
  - `Gacha.equip(s: State, kind: string, id: string?): boolean`
  - `Gacha.item(id: string): any?`

- [ ] **Step 1: 실패하는 테스트**

```lua
describe("Gacha", function()
	it("15 items, 2/2/1 per kind", function()
		local cnt = {}
		for _, it_ in Config.COSMETICS.items do
			local k = it_.kind .. ":" .. it_.rarity
			cnt[k] = (cnt[k] or 0) + 1
		end
		for _, kind in { "wing", "aura", "trail" } do
			expect(cnt[kind .. ":common"]).toBe(2); expect(cnt[kind .. ":rare"]).toBe(2); expect(cnt[kind .. ":legendary"]).toBe(1)
		end
	end)
	it("rarity boundaries", function()
		expect(Gacha.rarity(0.69)).toBe("common"); expect(Gacha.rarity(0.70)).toBe("rare")
		expect(Gacha.rarity(0.949)).toBe("rare"); expect(Gacha.rarity(0.95)).toBe("legendary")
	end)
	it("open adds new, refunds dup", function()
		local s = Gacha.newState()
		local a = Gacha.open(s, "wing", 0.1, 0.1) :: any
		expect(a.rarity).toBe("common"); expect(a.dup).toBe(false); expect(s.owned[a.id]).toBe(true)
		local b = Gacha.open(s, "wing", 0.1, 0.1) :: any
		expect(b.id).toBe(a.id); expect(b.dup).toBe(true); expect(b.refund).toBe(50)
		expect(Gacha.open(s, "hat", 0.1, 0.1)).toBe(nil)
	end)
	it("pity: 30th is legendary, resets", function()
		local s = Gacha.newState()
		for _ = 1, 29 do expect((Gacha.open(s, "aura", 0.1, 0.5) :: any).rarity).toBe("common") end
		expect((Gacha.open(s, "aura", 0.1, 0.5) :: any).rarity).toBe("legendary")
		expect(s.pity.aura).toBe(0)
		expect(s.pity.wing).toBe(0) -- 상자마다 따로
	end)
	it("equip validates", function()
		local s = Gacha.newState()
		local a = Gacha.open(s, "trail", 0.1, 0.1) :: any
		expect(Gacha.equip(s, "trail", a.id)).toBe(true); expect(s.equipped.trail).toBe(a.id)
		expect(Gacha.equip(s, "wing", a.id)).toBe(false) -- 다른 종류
		expect(Gacha.equip(s, "trail", "nope")).toBe(false)
		expect(Gacha.equip(s, "hat", nil)).toBe(false)
		expect(Gacha.equip(s, "trail", nil)).toBe(true); expect(s.equipped.trail).toBe(nil)
	end)
	it("clean drops junk", function()
		local s = Gacha.clean({ owned = { nope = true, [Config.COSMETICS.items[1].id] = true }, equipped = { wing = "nope" }, pity = { wing = -3, aura = "x" } })
		expect(s.owned.nope).toBe(nil); expect(s.owned[Config.COSMETICS.items[1].id]).toBe(true)
		expect(s.equipped.wing).toBe(nil); expect(s.pity.wing).toBe(0); expect(s.pity.aura).toBe(0)
		expect(Gacha.clean("garbage").pity.trail).toBe(0)
	end)
end)
```

- [ ] **Step 2:** `luau tests/run.luau` → FAIL
- [ ] **Step 3:** Config 블록 + `Gacha.luau` 구현
- [ ] **Step 4:** `/home/claude/check.sh` → `0 failed`
- [ ] **Step 5:** 커밋 `feat(shop): 꾸미기 15종과 뽑기 계산(확률·천장·환급)`

### Task 2: CoinService — 코인 저장·지급·기존 활동 연결

**Files:** Create `src/server/Services/CoinService.luau`; Modify `src/server/init.server.luau` (HeightService 다음), `MonsterService.luau:252` 근처, `BuildingService.luau:179` 근처, `BossService.luau:318` 근처, `QuestService.luau:56,60` 근처

**Interfaces:**
- Produces:
  - `CoinService.get(player): number`
  - `CoinService.add(player, n: number, reason: string)` — 정수로 내림, 0 이하 무시, 플레이어 속성 `Coins` 갱신, `extra.coins` 저장, 클라이언트에 `CoinGain(n)`(모듈 맨 위에서 `Remotes.get("CoinGain")`)
  - `CoinService.spend(player, n: number): boolean` — 모자라면 false, 상태 불변
  - 로드 시 `extra.coins`가 숫자 아니거나 음수면 0, 정수로 내림
  - 연결: 몬스터 처치 `Config.COINS.monster * zone`, 부수기 `smashPerFloor * floors`, 보스 보상 지급 시 `boss * zone`, 미션 `quest`/`questAll`

- [ ] **Step 1:** 구현 → **Step 2:** `/home/claude/check.sh` → `0 failed`, 경고 0 → **Step 3:** 커밋 `feat(shop): 코인 벌기`

### Task 3: ShopService — 상자 열기·착용·공개

**Files:** Create `src/server/Services/ShopService.luau`; Modify `src/server/init.server.luau` (CoinService 다음)

**Interfaces:**
- Consumes: `Gacha`, `CoinService.spend/add`, `DataService.extra`
- Produces:
  - 리모트(모듈 맨 위에서 생성): `OpenBox(kind)` 클→서, `BoxResult(result: {id, rarity, name, dup, refund, kind})` 서→클, `EquipCosmetic(kind, id?)` 클→서
  - 열기: `CoinService.spend(price)` 성공일 때만 `Gacha.open(s, kind, math.random(), math.random())`; 중복이면 `CoinService.add(refund, "refund")`; 새 아이템이고 그 종류 빈칸이면 자동 착용; 전설이면 `Remotes.notifyAll(이름 .. "님이 전설 " .. 아이템 .. " 획득!")`; 처리 중 플래그로 연타 방지
  - 공개 속성: `Cosmetics` (JSON `{wing, aura, trail}`), `CosmeticState` (JSON `{owned: {id…}, pity: {...}}`, 본인 UI용)
  - 저장: `extra.cosmetics = state`

- [ ] **Step 1:** 구현 → **Step 2:** `/home/claude/check.sh` 통과, `python3 -m pytest tests/py -q`(리모트 테스트 포함) 통과 → **Step 3:** 커밋 `feat(shop): 상자 열기·착용 서버`

### Task 4: ShopClient — 코인 표시·상점 창·여는 연출

**Files:** Create `src/client/ShopClient.luau`; Modify `src/client/init.client.luau`

**Interfaces:**
- Consumes: 속성 `Coins`, `CosmeticState`, `Cosmetics`; 리모트 `CoinGain`, `OpenBox`, `BoxResult`, `EquipCosmetic`
- Produces: 오른쪽 위 코인 표시(`Panels`의 따라잡기 표시(y=126) 아래, y=156) + "+N 코인" 떠오름; 왼쪽 **상점** 버튼(`UDim2.new(0, 8, 0.25, 150)`); 상점 창(상자 3개: 이름·가격·확률·"전설까지 N번", 열기 버튼; 아래 착용 탭 3개: 보유 목록, 눌러서 착용/해제); `BoxResult` → 1.2초 빙글빙글 후 등급 색(일반 회색, 희귀 파랑, 전설 금색)으로 이름 표시, 중복이면 "+50 코인 환급"

- [ ] **Step 1:** 구현 → **Step 2:** `/home/claude/check.sh` 통과 → **Step 3:** 커밋 `feat(shop): 상점 창과 상자 연출`

### Task 5: Cosmetics — 날개·오라·발자국 그리기

**Files:** Create `src/client/Cosmetics.luau`; Modify `src/client/init.client.luau`

**Interfaces:**
- Consumes: 모든 플레이어의 `Cosmetics`, `Height` 속성, `Config.COSMETICS.items`(색), `Growth.heightToScale`
- Produces: 날개 = 등 뒤 파트(좌우 쌍, 파닥임 sin, 전설 Neon); 오라 = 루트를 따라가는 투명 파트의 ParticleEmitter(아이템 색, 전설 Rate·LightEmission 높게); 발자국 = 보폭 `2·scale`마다 아래로 레이캐스트한 땅에 납작한 파트(아이템 색, 크기 ∝ scale), 3초 뒤 삭제, 플레이어당 큐 최대 20(넘으면 가장 오래된 것 삭제); 장비 바뀌거나 플레이어 나가면 정리

- [ ] **Step 1:** 구현 → **Step 2:** `/home/claude/check.sh` 통과 → **Step 3:** 커밋 `feat(shop): 날개·오라·발자국 그리기`

### Task 6: Studio 플레이 테스트와 문서

**Files:** Modify `docs/PLAYTEST.md` (23번), `README.md`

- [ ] **Step 1:** (사용자 연결 후) MCP 플레이: 콘솔 에러 없음
- [ ] **Step 2:** MCP Server: 테스트 플레이어에 `CoinService.add(1000)` → 상자 열기 10번 결과·코인 감소·천장 카운트, 착용 → 클라이언트에 날개·오라 파트/파티클 존재, 걸으면 발자국 ≤ 20
- [ ] **Step 3:** 스크린샷(날개+오라+발자국), 문서 갱신, `/home/claude/check.sh` 통과, 커밋·푸시
