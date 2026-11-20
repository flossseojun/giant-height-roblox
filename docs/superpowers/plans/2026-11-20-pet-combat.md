# 펫 고도화(키우기 + 몬스터 전투) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 펫이 레벨업·진화하고, 구역마다 돌아다니는 몬스터와 싸우며(자동 공격·집중·필살기·밟기), 길들이기/보스로 새 펫을 얻고, 팀 3마리를 데리고 다니게 한다.

**Architecture:** 계산은 순수 Logic 모듈 3개(PetProgress, PetData, MonsterCombat)로 떼어 luau 테스트. 서버는 PetService(데이터·경험치·팀·배율)와 새 MonsterService(출현·배회·전투 틱·보상·길들이기)로 나누고, BossService에 펫 공격을 붙인다. 출현 지점은 genmap이 `MonsterSpawn` 태그로 맵에 넣는다. 클라이언트는 PetClient(펫 그리기·펫 창·HUD)를 개편한다.

**Tech Stack:** Luau, Rojo 7.6, luau CLI 테스트(tests/run.luau), Python genmap/pytest, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-20-pet-combat-design.md`

## Global Constraints

- 모든 숫자는 `src/shared/Config.luau`에. 서버 권한(클라이언트 요청은 서버가 검증).
- 몬스터는 **플레이어를 때리거나 멈추게 하지 않는다**. 펫만 공격.
- 팀 최대 3, 보유 최대 30, 최대 레벨 50, 진화 15·35레벨, 진화배율 {1, 1.5, 2.2}.
- `xpToNext(L) = round(10·L^1.5)`; `stat = base·(1+0.12·(L−1))·진화배율`.
- 팀 성장 배율 = 팀에서 가장 큰 `mult + 0.01·L` (곱하지 않음). 줍기 반경 = 가장 큰 `radius·(1+0.02·L)`. 팀이 비면 배율 1, 반경 0.
- 전투 틱 0.25초, 펫 기본 공격 1초마다, 기절 10초, 집중 사거리 = 기본 사거리 ×2.
- 필살기 유형: `burst`(단일 5배), `aoe`(반경 10 안 전부 2배), `heal`(팀 최대체력 40% 회복), 쿨타임 12~20초.
- 밟기: 반경 `3·scale`, 데미지 `BossFight.damageFor(scale)`.
- 길들이기: 흔함 0.08, 드묾 0.03, 버튼 8초. 보스 펫은 처음 한 번 확정.
- 출현 지점당 최대 3마리, 리스폰 20초, 동시 상한 1구역 24 / 2~4구역 12.
- 저장: `extra.pets = {owned={{uid,kind,level,xp}}, team={uid…}, nextId}`. 기존 `extra.pet`에서 변환. 환생해도 유지.
- 1구역 맵 파트 예산 13,000 유지. 커밋 메시지 끝에 Co-Authored-By/Claude-Session 줄.

## Review Focus

- 예전 저장(`extra.pet = "otter"`, `extra.pets` 없음)으로 접속 → 키로 열린 펫이 보유에 들어가고 팀에 otter, 데이터 손실 없음.
- 클라이언트가 보유하지 않은 uid·중복 uid·4마리 팀을 보내거나 남의 몬스터 id를 집중/밟기 요청 → 서버가 거절, 상태 불변.
- 펫이 모두 기절한 팀 / 팀이 빈 플레이어 → 몬스터가 아무도 못 때리고 에러 없음, 성장 배율 1.
- 몬스터가 사라진(처치·리스폰) 순간 도착한 집중·필살기 요청 → 무시, 에러 없음.
- 플레이어가 나간 뒤 그 플레이어를 노리던 몬스터 / 그 플레이어의 길들이기 제안 → 정리되고 누수 없음.

---

### Task 1: PetProgress — 레벨·진화·능력치·팀 보너스

**Files:**
- Create: `src/shared/Logic/PetProgress.luau`
- Modify: `src/shared/Config.luau` (PET_SPECIES, PET 블록 추가; 기존 `Config.PETS`는 Task 5에서 제거)
- Test: `tests/pets.spec.luau` (새 파일, `tests/run.luau` specs 목록에 추가)

**Interfaces:**
- Produces:
  - `Config.PET = { maxLevel=50, evoLevels={15,35}, evoMult={1,1.5,2.2}, maxTeam=3, maxOwned=30, faintTime=10, attackEvery=1, tick=0.25, baseRange=14, focusMult=2, tameWindow=8, foodXp=1, statPerLevel=0.12 }`
  - `Config.PET_SPECIES: { [string]: Species }` — `Species = { id, name, stages={string,string,string}, zone, how="height"|"tame"|"boss", minHeight?, tameChance?, atk, hp, mult, radius, skill={kind, cooldown, name}, monster?={hp, atk, attackEvery, xp, gainMult} }`. 13종: cat/otter/squirrel(height), pigeon/duck(z1 tame), carp/heron(z2), boar/crow(z3), star(z4), hotteok/catfish/cloud(boss). `cat/otter/squirrel`의 minHeight·mult·radius는 기존 `Config.PETS` 값 그대로.
  - `PetProgress.xpToNext(level: number): number`
  - `PetProgress.addXp(level: number, xp: number, gain: number): (number, number, number)` → (새 레벨, 남은 xp, 오른 레벨 수). 최대 레벨이면 xp 0으로 고정.
  - `PetProgress.stage(level: number): number` → 1|2|3
  - `PetProgress.stat(base: number, level: number): number`
  - `PetProgress.teamBonus(members: {{species: Species, level: number}}): (number, number)` → (mult, radius)

- [ ] **Step 1: 실패하는 테스트 작성** (`tests/pets.spec.luau`)

```lua
describe("PetProgress", function()
	it("xp curve", function()
		expect(PetProgress.xpToNext(1)).toBe(10)
		expect(PetProgress.xpToNext(4)).toBe(80)
	end)
	it("addXp levels up and carries over", function()
		local l, x, up = PetProgress.addXp(1, 5, 20) -- 25: 10 → L2(28 필요) 남음 15
		expect(l).toBe(2); expect(x).toBe(15); expect(up).toBe(1)
		local l2, x2 = PetProgress.addXp(50, 0, 99999)
		expect(l2).toBe(50); expect(x2).toBe(0)
	end)
	it("stage", function()
		expect(PetProgress.stage(14)).toBe(1); expect(PetProgress.stage(15)).toBe(2)
		expect(PetProgress.stage(35)).toBe(3)
	end)
	it("stat", function()
		expect(PetProgress.stat(10, 1)).toBeCloseTo(10)
		expect(PetProgress.stat(10, 15)).toBeCloseTo(10 * (1 + 0.12 * 14) * 1.5)
	end)
	it("team bonus is best, not product", function()
		local S = Config.PET_SPECIES
		local m, r = PetProgress.teamBonus({ { species = S.cat, level = 1 }, { species = S.otter, level = 10 } })
		expect(m).toBeCloseTo(1.25 + 0.10); expect(r).toBeCloseTo(14 * 1.2)
		local m0, r0 = PetProgress.teamBonus({})
		expect(m0).toBe(1); expect(r0).toBe(0)
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
			if s.how == "tame" then expect(s.tameChance == 0.08 or s.tameChance == 0.03).toBe(true) end
			if s.how ~= "height" then expect(s.monster ~= nil or s.how == "boss").toBe(true) end
		end
		expect(n).toBe(13)
	end)
end)
```

- [ ] **Step 2: 실행해 실패 확인** — Run: `luau tests/run.luau` → Expected: `pets.spec (불러오기 실패)` 또는 PetProgress 테스트 FAIL
- [ ] **Step 3: Config 블록과 `PetProgress.luau` 구현**
- [ ] **Step 4: 통과 확인** — Run: `/home/claude/check.sh` → Expected: `0 failed`, `map ok`, `build ok`
- [ ] **Step 5: 커밋** — `git commit -m "feat(pets): 펫 종류 13종과 레벨·진화·능력치 계산"`

### Task 2: PetData — 보유·팀·저장 변환

**Files:**
- Create: `src/shared/Logic/PetData.luau`
- Test: `tests/pets.spec.luau`

**Interfaces:**
- Consumes: `Config.PET_SPECIES`, `Config.PET.maxTeam/maxOwned`
- Produces (`Data = {owned: {Entry}, team: {number}, nextId: number}`, `Entry = {uid: number, kind: string, level: number, xp: number}`):
  - `PetData.migrate(extra: {[string]: any}, species, bestHeight: number): Data` — `extra.pets`가 올바르면 그대로(잘못된 entry·없는 kind는 버림), 아니면 키로 열린 height 종을 L1로 넣고 팀 = {예전 `extra.pet` 종의 uid} (없으면 cat).
  - `PetData.add(d: Data, kind: string): number?` — 꽉 차면 nil
  - `PetData.find(d: Data, uid: any): Entry?`
  - `PetData.setTeam(d: Data, uids: any): boolean` — 표 아님/4개 이상/중복/미보유 → false, 상태 불변
  - `PetData.unlockByHeight(d: Data, species, height: number): {string}` — 새로 넣은 kind 목록(이미 보유한 종은 다시 안 넣음)
  - `PetData.teamEntries(d: Data): {Entry}`

- [ ] **Step 1: 실패하는 테스트**

```lua
describe("PetData", function()
	local S = Config.PET_SPECIES
	it("migrates old save", function()
		local d = PetData.migrate({ pet = "otter" }, S, 2000)
		expect(#d.owned).toBe(2) -- cat, otter
		local t = PetData.teamEntries(d)
		expect(#t).toBe(1); expect(t[1].kind).toBe("otter")
	end)
	it("keeps valid new save, drops broken entries", function()
		local d = PetData.migrate({ pets = { owned = { { uid = 1, kind = "duck", level = 3, xp = 2 }, { uid = 2, kind = "nope", level = 1, xp = 0 } }, team = { 1, 2 }, nextId = 3 } }, S, 0)
		expect(#d.owned).toBe(1); expect(#d.team).toBe(1)
	end)
	it("setTeam validates", function()
		local d = PetData.migrate({}, S, 200000)
		local a, b, c = d.owned[1].uid, d.owned[2].uid, d.owned[3].uid
		expect(PetData.setTeam(d, { a, a })).toBe(false)
		expect(PetData.setTeam(d, { a, 999 })).toBe(false)
		expect(PetData.setTeam(d, "x")).toBe(false)
		local x = PetData.add(d, "duck") :: number
		expect(PetData.setTeam(d, { a, b, c, x })).toBe(false)
		expect(PetData.setTeam(d, { c, a })).toBe(true); expect(d.team[1]).toBe(c)
	end)
	it("add respects cap", function()
		local d = PetData.migrate({}, S, 0)
		for _ = 1, 40 do PetData.add(d, "pigeon") end
		expect(#d.owned).toBe(30); expect(PetData.add(d, "pigeon")).toBe(nil)
	end)
	it("unlockByHeight adds once", function()
		local d = PetData.migrate({}, S, 0)
		expect(#PetData.unlockByHeight(d, S, 1000)).toBe(1)
		expect(#PetData.unlockByHeight(d, S, 1000)).toBe(0)
	end)
end)
```

- [ ] **Step 2: 실패 확인** — `luau tests/run.luau` → PetData FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — `/home/claude/check.sh` → `0 failed`
- [ ] **Step 5: 커밋** — `feat(pets): 보유·팀·예전 저장 변환`

### Task 3: MonsterCombat — 목표 고르기·기절·필살기·밟기·길들이기

**Files:**
- Create: `src/shared/Logic/MonsterCombat.luau`
- Test: `tests/pets.spec.luau`

**Interfaces:**
- Consumes: `BossFight.damageFor`, `Config.PET`
- Produces:
  - `MonsterCombat.pickTarget(monsters: {{id: any, pos: Vector3, hp: number}}, origin: Vector3, range: number, focusId: any?): any?` — focus가 살아 있고 `range·focusMult` 안이면 그것, 아니면 range 안 가장 가까운 살아 있는 몬스터
  - `MonsterCombat.newPetState(maxHp: number): PetState` (`{hp, maxHp, reviveAt: number?}`)
  - `MonsterCombat.damagePet(s: PetState, dmg: number, now: number): boolean` — 기절하면 true, reviveAt = now+faintTime
  - `MonsterCombat.tickRevive(s: PetState, now: number): boolean` — 회복하면 true(hp=maxHp)
  - `MonsterCombat.alive(s: PetState): boolean`
  - `MonsterCombat.skillReady(last: number?, cooldown: number, now: number): boolean`
  - `MonsterCombat.skillEffect(kind: string, atk: number, target: any?, monsters, origin: Vector3): ({[any]: number}, number)` → (몬스터별 데미지, 팀 회복 비율). burst=target에 5·atk, aoe=origin 반경 10 안 전부 2·atk, heal=({}, 0.4)
  - `MonsterCombat.stomp(monsters, at: Vector3, scale: number): {[any]: number}`
  - `MonsterCombat.monsterStats(sp: Species, zoneK: number): (hp, atk, xp)` — `monster.hp·zoneK`, `monster.atk·zoneK`, `monster.xp`
  - `MonsterCombat.tameRoll(chance: number, r: number): boolean` — `r < chance`

- [ ] **Step 1: 실패하는 테스트**

```lua
describe("MonsterCombat", function()
	local M = {
		{ id = 1, pos = Vector3.new(5, 0, 0), hp = 10 },
		{ id = 2, pos = Vector3.new(20, 0, 0), hp = 10 },
		{ id = 3, pos = Vector3.new(3, 0, 0), hp = 0 },
	}
	it("pickTarget nearest alive, honors focus within 2x", function()
		expect(MonsterCombat.pickTarget(M, Vector3.zero, 14, nil)).toBe(1)
		expect(MonsterCombat.pickTarget(M, Vector3.zero, 14, 2)).toBe(2)
		expect(MonsterCombat.pickTarget(M, Vector3.zero, 8, 2)).toBe(1) -- 20 > 16
		expect(MonsterCombat.pickTarget(M, Vector3.zero, 14, 3)).toBe(1) -- 죽은 집중 대상 무시
		expect(MonsterCombat.pickTarget({}, Vector3.zero, 14, nil)).toBe(nil)
	end)
	it("faint and revive", function()
		local s = MonsterCombat.newPetState(10)
		expect(MonsterCombat.damagePet(s, 4, 0)).toBe(false)
		expect(MonsterCombat.damagePet(s, 9, 1)).toBe(true)
		expect(MonsterCombat.alive(s)).toBe(false)
		expect(MonsterCombat.tickRevive(s, 10)).toBe(false)
		expect(MonsterCombat.tickRevive(s, 11)).toBe(true); expect(s.hp).toBe(10)
	end)
	it("skills", function()
		local d = MonsterCombat.skillEffect("burst", 3, 1, M, Vector3.zero)
		expect(d[1]).toBe(15)
		local a = MonsterCombat.skillEffect("aoe", 3, nil, M, Vector3.zero)
		expect(a[1]).toBe(6); expect(a[2]).toBe(nil)
		local _, heal = MonsterCombat.skillEffect("heal", 3, nil, M, Vector3.zero)
		expect(heal).toBeCloseTo(0.4)
		expect(MonsterCombat.skillReady(nil, 12, 0)).toBe(true)
		expect(MonsterCombat.skillReady(5, 12, 10)).toBe(false)
	end)
	it("stomp radius scales", function()
		local hit = MonsterCombat.stomp(M, Vector3.zero, 2) -- 반경 6
		expect(hit[1]).toBe(BossFight.damageFor(2)); expect(hit[2]).toBe(nil)
	end)
	it("tameRoll", function()
		expect(MonsterCombat.tameRoll(0.08, 0.079)).toBe(true)
		expect(MonsterCombat.tameRoll(0.08, 0.08)).toBe(false)
	end)
end)
```

- [ ] **Step 2: 실패 확인** — `luau tests/run.luau` → MonsterCombat FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — `/home/claude/check.sh` → `0 failed`
- [ ] **Step 5: 커밋** — `feat(pets): 몬스터 전투 계산(목표·기절·필살기·밟기·길들이기)`

### Task 4: 맵 — MonsterSpawn 출현 지점

**Files:**
- Modify: `tools/osm/zone1.py` (반환 dict에 `monster_spawns: [(x, z, species, radius)]` 추가)
- Modify: `tools/genmap.py` (1구역 + 2~4구역 zone_folder에 `MonsterSpawn` 센서 추가)
- Modify: `tools/map_check.py`
- Test: `tests/py/test_osm_zone1.py`

**Interfaces:**
- Produces: 태그 `MonsterSpawn` 파트(투명, CanCollide false), 속성 `Zone`(number), `Species`(string), `Radius`(number). 1구역: `pigeon` 지점 ≥ 4 (시장 골목 street_pts 주변과 역 광장), `duck` 지점 ≥ 3 (양근천 물길에서 10~20스터드 떨어진 땅). 2구역 carp/heron, 3구역 boar/crow, 4구역 star 각 ≥ 2.

- [ ] **Step 1: 실패하는 테스트** (`tests/py/test_osm_zone1.py`)

```python
def test_monster_spawns_on_land_not_in_buildings(z1):
    sp = z1["monster_spawns"]
    kinds = [s[2] for s in sp]
    assert kinds.count("pigeon") >= 4 and kinds.count("duck") >= 3
    obs = Obstacles(z1["_building_polys"])
    for x, z, kind, r in sp:
        assert not obs.hit(x, z, 2), (x, z, kind)
        assert 8 <= r <= 30
```
(`z1` fixture가 없으면 `build_zone1` 결과를 모듈 범위로 캐시하는 fixture를 같은 파일에 추가하고, `build_zone1`이 `_building_polys`를 반환하도록 한다.)

map_check: `expected.update({("MonsterSpawn", z): 2 for z in (2, 3, 4)})`, 1구역은 최소 7.

- [ ] **Step 2: 실패 확인** — Run: `python3 -m pytest tests/py -q` → Expected: FAIL (KeyError 'monster_spawns')
- [ ] **Step 3: zone1.py·genmap.py·map_check.py 구현** (물길은 기존 water ways, 시장은 `street_pts`)
- [ ] **Step 4: 통과 확인** — Run: `python3 tools/genmap.py && python3 -m pytest tests/py -q && /home/claude/check.sh` → Expected: 모두 통과, `map ok`
- [ ] **Step 5: 맵 빌드 후 커밋** — `rojo build map.project.json -o map/BaseMap.rbxm`; `feat(map): 몬스터 출현 지점`

### Task 5: PetService — 데이터·경험치·팀·배율

**Files:**
- Modify: `src/server/Services/PetService.luau` (전면 개편)
- Modify: `src/shared/Config.luau` (기존 `Config.PETS` 제거), `src/shared/Logic/Pets.luau` 삭제 및 참조 정리(`grep -rn "Config.PETS\|Logic.Pets"`)
- Modify: `tests/*.spec.luau`에서 `Config.PETS`/`Pets` 쓰는 테스트를 PET_SPECIES 기준으로 수정

**Interfaces:**
- Consumes: Task 1~3 Logic, `HeightService.onGain/onChanged/setPetMult/best/get`, `DataService.extra`, `FoodService.edibleParts/tryEat`, `Remotes.get/notify`
- Produces:
  - `PetService.data(player): PetData.Data?`
  - `PetService.team(player): {{entry: Entry, species: Species, state: PetState, atk: number}}` — MonsterService·BossService가 씀(체력 상태 포함, 팀 바뀌면 다시 만듦)
  - `PetService.giveXp(player, uids: {number}?, amount: number)` — nil이면 팀 전원. 레벨업/진화 시 `Remotes.notify` + `Remotes.sfx(player, "levelup")`
  - `PetService.addPet(player, kind: string): boolean`
  - `PetService.publish(player)` — 플레이어 속성 `PetTeam`(JSON: `[{uid,kind,level,stage,hp,maxHp,skillReadyAt}]`)과 `PetOwned`(JSON 목록) 갱신
  - 리모트: `SetTeam(uids)`(PetData.setTeam), 기존 `EquipPet`은 제거
  - 음식 경험치: `onGain` source가 `"food"`일 때 팀 전원 `Config.PET.foodXp · zone k`
  - 배율/줍기: 팀 바뀔 때·레벨업 때 `HeightService.setPetMult(teamBonus mult)`, 줍기 루프는 teamBonus radius 사용
  - 키 해금: onChanged에서 `PetData.unlockByHeight` → 알림
  - 저장: 변경 시 `DataService.extra(player).pets = data`

- [ ] **Step 1: 정적 검사 + 기존 테스트가 PETS 제거로 깨지는지 확인** — Run: `/home/claude/check.sh` (Config.PETS 제거 직후) → Expected: 참조 에러로 FAIL
- [ ] **Step 2: 구현** (Logic은 이미 테스트됨; 서비스는 연결만)
- [ ] **Step 3: 통과 확인** — Run: `/home/claude/check.sh` → Expected: `0 failed`, luau-lsp 경고 0
- [ ] **Step 4: 커밋** — `feat(pets): PetService 개편(팀 3마리·경험치·저장 변환)`

### Task 6: MonsterService — 출현·배회·전투·보상·길들이기

**Files:**
- Create: `src/server/Services/MonsterService.luau`
- Modify: `src/server/init.server.luau` (order에 `"MonsterService"`를 PetService 뒤에)
- Modify: `src/shared/Config.luau` (`Config.MONSTER = { respawn=20, perSpawn=3, zoneCap={24,12,12,12}, wanderSpeed=6, tameWindow=8, stompCooldown=0.8 }`)

**Interfaces:**
- Consumes: `MonsterCombat`, `PetService.team/giveXp/addPet/publish`, `HeightService.add/get/zoneConfig`, `Zones.bestGain`, `Growth.heightToScale`, CollectionService `MonsterSpawn`
- Produces:
  - 몬스터 모델: `workspace.Monsters` 폴더, 모델 속성 `MonsterId`, `Species`, `Hp`, `MaxHp`; ClickDetector(MaxActivationDistance 200); 머리 위 BillboardGui 체력바
  - 리모트: `FocusMonster(id)`, `PetSkill(slot)`, `Stomp()`(클라이언트가 착지 시 보냄; 서버가 쿨타임·캐릭터 위치로 검증), `Tame(offerId)`; 서버→클라 `TameOffer(offerId, kind)`
  - 보상: 처치 시 참여한 펫 `giveXp(monster.xp)`, 마지막 타격 플레이어에게 `HeightService.add(bestGain·gainMult, "monster")`, `tameChance` 성공 시 `TameOffer`
  - 정리: PlayerRemoving 시 그 플레이어의 focus·offer·쿨타임 삭제

- [ ] **Step 1: 구현** (계산은 MonsterCombat; 서비스는 Roblox 연결)
- [ ] **Step 2: 정적 검사** — Run: `/home/claude/check.sh` → Expected: `0 failed`, 경고 0, `build ok`
- [ ] **Step 3: 커밋** — `feat(pets): 몬스터 출현·전투·보상·길들이기`

### Task 7: BossService — 펫 참여와 보스 펫

**Files:**
- Modify: `src/server/Services/BossService.luau`
- Modify: `src/shared/Config.luau` (BOSSES에 `pet = "hotteok"|"catfish"|"cloud"`)

**Interfaces:**
- Consumes: `PetService.team/addPet/data`, `MonsterCombat.alive`
- Produces: 보스 싸움 중 매 `Config.PET.attackEvery`초, 보스 반경 `Config.PET.baseRange·scale` 안 플레이어의 살아 있는 팀 펫마다 `fight.hit("pet:" .. uid .. ":" .. slot, atk, now)`. 처치 시 참여 플레이어가 그 보스 펫을 보유하지 않았으면 `PetService.addPet` + 알림.

- [ ] **Step 1: 테스트** (`tests/pets.spec.luau`) — `Config.BOSSES`의 각 `pet`이 `PET_SPECIES`의 `how="boss"` 종인지 검사; 실패 확인
- [ ] **Step 2: 구현** → **Step 3:** `/home/claude/check.sh` → `0 failed` → **Step 4: 커밋** `feat(pets): 보스전 펫 참여·보스 펫`

### Task 8: PetClient — 펫 그리기·펫 창·HUD·길들이기·착지

**Files:**
- Modify: `src/client/PetClient.luau` (전면 개편)

**Interfaces:**
- Consumes: 속성 `PetTeam`/`PetOwned`(JSON), 몬스터 모델 속성, 리모트 `SetTeam/FocusMonster/PetSkill/Stomp/Tame/TameOffer`
- Produces:
  - 모든 플레이어의 팀 펫(최대 3)을 따라다니게 그림, 진화 단계별 크기 1/1.4/1.9배와 종별 색·꼬리, 주인이 싸우는 중이면 목표 몬스터 쪽으로 붙는 연출
  - 펫 창(기존 '펫' 버튼): 보유 목록(이름·단계 이름·레벨·xp 막대), 팀 칸 3개, 눌러서 넣기/빼기 → `SetTeam`
  - HUD: 팀 펫 체력바 3개 + 필살기 버튼(쿨타임 표시) → `PetSkill(slot)`
  - 몬스터 ClickDetector 클릭/터치 → `FocusMonster(id)`
  - 내 Humanoid `StateChanged` Landed(낙하 속도 기준) → `Stomp()`
  - `TameOffer` → 8초짜리 "길들이기!" 버튼 → `Tame(offerId)`

- [ ] **Step 1: 구현** → **Step 2:** `/home/claude/check.sh` → `0 failed`, 경고 0 → **Step 3: 커밋** `feat(pets): 펫 창·HUD·길들이기 화면`

### Task 9: Studio 플레이 테스트와 문서

**Files:**
- Modify: `docs/PLAYTEST.md` (펫·몬스터 항목 추가), `README.md` (펫 시스템 한 단락)

- [ ] **Step 1:** 사용자가 Pull + 새 BaseMap 넣기 → MCP `start_stop_play`로 플레이, `get_console_output`에 에러 없음 확인
- [ ] **Step 2:** MCP `execute_luau`(Server)로 확인: `workspace.Monsters` 자식 수 > 0 (1구역 ≤ 24), 테스트 플레이어 팀 펫 공격으로 몬스터 Hp 감소, `PetService.addPet` 후 `PetOwned` 갱신, 예전 저장 모양(`extra.pet="otter"`)으로 migrate 결과
- [ ] **Step 3:** 문서 갱신, `/home/claude/check.sh` 통과, 커밋·푸시 `docs: 펫·몬스터 플레이테스트 항목`
