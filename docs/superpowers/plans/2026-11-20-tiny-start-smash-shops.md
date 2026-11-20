# 10cm 시작 · 건물 부수기 · 가게 생김새 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 키 10cm에서 작은 몸으로 시작하고, 착지로 내 키보다 작은 건물을 부숴 키를 얻고(60초 뒤 복구), 상가가 글씨 없이 가게 종류별 생김새를 갖게 한다.

**Architecture:** 몸 크기는 `Growth.heightToScale`에 150cm 미만 구간을 추가. 부수기 판정·보상·복구 조건은 새 순수 모듈 `Logic/Smash`에 두고 luau 테스트. genmap이 건물을 `Building_<id>` 모델(+`Breakable` 태그, `Floors`·`HeightCm` 속성)로 묶고, 새 `BuildingService`가 기존 `Stomp` 리모트를 받아 숨기기·돌무더기·복구, 클라이언트 `SmashFx`가 잔해 연출. 가게 생김새는 `tools/osm/buildings.py`(상가)와 `landmarks.py`(시장 아케이드)에서 글씨 대신 장식 파트로.

**Tech Stack:** Luau, Rojo 7.6, luau CLI 테스트, Python genmap/pytest, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-20-tiny-start-smash-shops-design.md`

## Global Constraints

- `Config.START_HEIGHT = 10`. 150cm 미만 몸 크기 `(h/150)^0.45`, 150cm 이상은 기존 공식.
- 건물 키 = `Floors × 300` cm. 부수려면 내 키 > 건물 키. 착지로만(기존 `Stomp` 리모트).
- 판정 반경: 발에서 수평 거리 ≤ 건물 반지름 + `3·scale`. 한 번 착지에 최대 3채.
- 보상 `Zones.bestGain(구역) × Floors × 5`, 소스 `"smash"` (Quests 특수 소스).
- 복구 60초, 그 자리에 플레이어가 있으면 3초씩 미룸. 부서진 동안 다시 못 부숨.
- 키 모자람 안내 문구 `"건물 Nm — 키가 더 커야 해요!"`, 같은 플레이어에게 5초에 한 번.
- 돌무더기 3조각(서버, 앵커), 잔해 8조각(클라이언트, 2초 뒤 삭제).
- 양평역·정류장·시장 아케이드·로터리는 `Breakable` 아님. 오스타 이름판은 오스타 건물 모델 안.
- 일반 건물 파트에 글씨(label) 없음. 랜드마크 이름(양평역, 시장1길, 오스타 코아루)은 유지.
- 1구역 파트 ≤ 15,000. 커밋 끝에 Co-Authored-By/Claude-Session 줄.

## Review Focus

- 부서진 건물이 복구될 때 원래 투명도·충돌·SurfaceGui·CanQuery가 정확히 돌아오는가(원래 투명했던 파트는 투명하게).
- 같은 건물을 두 사람이 동시에 밟음 → 한 번만 부서지고 보상은 먼저 밟은 사람.
- 부서진 건물 안/위에 서 있던 플레이어 → 떨어질 뿐 에러 없음, 복구 때 몸이 박히지 않음.
- 플레이어가 나가거나 리셋한 직후 도착한 Stomp → 무시.
- 10cm 몸으로 음식 줍기·문 통과·어깨 타기·펫 따라오기가 깨지지 않음(카메라 땅속 X).

---

### Task 1: 10cm 시작과 작은 몸

**Files:** Modify `src/shared/Logic/Growth.luau`, `src/shared/Config.luau`; Test `tests/logic.spec.luau`

**Interfaces:**
- Produces: `Growth.heightToScale(height, k, maxScale)` — `height < 150`이면 `(height/150)^0.45` (0 이하·NaN은 `(10/150)^0.45`로 처리), 이상은 기존.

- [ ] **Step 1: 테스트 수정·추가** (`tests/logic.spec.luau`의 heightToScale 블록)

```lua
expect(Growth.heightToScale(100, 1.5, 12)).toBeCloseTo((100 / 150) ^ 0.45)
expect(Growth.heightToScale(10, 1.5, 12)).toBeCloseTo(0.296, 0.01)
expect(math.abs(Growth.heightToScale(149.999, 1.5, 12) - 1) < 0.001).toBe(true)
expect(Growth.heightToScale(0, 1.5, 12)).toBeCloseTo((10 / 150) ^ 0.45)
expect(Config.START_HEIGHT).toBe(10)
```
(harness `toBeCloseTo`의 허용 오차 인자가 없으면 `math.abs(...) < 0.01` 형태로.)

- [ ] **Step 2:** `luau tests/run.luau` → FAIL (100 → 1)
- [ ] **Step 3:** 구현 (`Config.START_HEIGHT = 10`)
- [ ] **Step 4:** `/home/claude/check.sh` → `0 failed`
- [ ] **Step 5:** 커밋 `feat: 10cm에서 작은 몸으로 시작`

### Task 2: Smash — 부수기 판정·보상·복구 조건

**Files:** Create `src/shared/Logic/Smash.luau`; Modify `src/shared/Config.luau`, `src/shared/Logic/Quests.luau`; Test `tests/smash.spec.luau` (run.luau에 추가)

**Interfaces:**
- Produces:
  - `Config.SMASH = { cmPerFloor = 300, maxPerStomp = 3, rewardPerFloor = 5, respawn = 60, restoreRetry = 3, hintCooldown = 5, rubble = 3, debris = 8, cooldown = 0.8 }`
  - `Smash.heightCm(floors: number): number`
  - `Smash.targets(buildings: {{id: any, x: number, z: number, radius: number, heightCm: number, brokenUntil: number?}}, feet: {X: number, Z: number}, scale: number, playerHeight: number, now: number): ({any}, {any})` → (부술 id 최대 3개, 가까운 순 / 키가 모자란 id들)
  - `Smash.reward(bestGain: number, floors: number): number`
  - `Smash.canRestore(b: {x, z, radius}, players: {{X: number, Z: number}}): boolean`
  - Quests 특수 소스에 `smash`

- [ ] **Step 1: 실패하는 테스트**

```lua
local B = function(id, x, h, until_) return { id = id, x = x, z = 0, radius = 5, heightCm = h, brokenUntil = until_ } end
describe("Smash", function()
	it("heightCm", function() expect(Smash.heightCm(4)).toBe(1200) end)
	it("breaks only shorter buildings in reach, nearest first, max 3", function()
		local bs = { B(1, 6, 600), B(2, 2, 600), B(3, 7, 600), B(4, 4, 600), B(5, 3, 5000), B(6, 50, 100) }
		local hit, tall = Smash.targets(bs, { X = 0, Z = 0 }, 1, 1000, 0)
		expect(#hit).toBe(3); expect(hit[1]).toBe(2); expect(hit[2]).toBe(4); expect(hit[3]).toBe(1)
		expect(#tall).toBe(1); expect(tall[1]).toBe(5)
	end)
	it("skips broken until restored", function()
		local hit = Smash.targets({ B(1, 0, 100, 30) }, { X = 0, Z = 0 }, 1, 1000, 10)
		expect(#hit).toBe(0)
		local hit2 = Smash.targets({ B(1, 0, 100, 30) }, { X = 0, Z = 0 }, 1, 1000, 31)
		expect(#hit2).toBe(1)
	end)
	it("equal height does not break", function()
		local hit = Smash.targets({ B(1, 0, 1000) }, { X = 0, Z = 0 }, 1, 1000, 0)
		expect(#hit).toBe(0)
	end)
	it("reach grows with scale", function()
		expect(#Smash.targets({ B(1, 20, 100) }, { X = 0, Z = 0 }, 1, 1000, 0)).toBe(0)
		expect(#Smash.targets({ B(1, 20, 100) }, { X = 0, Z = 0 }, 5, 1000, 0)).toBe(1)
	end)
	it("reward", function() expect(Smash.reward(3, 4)).toBe(60) end)
	it("canRestore", function()
		expect(Smash.canRestore({ x = 0, z = 0, radius = 5 }, { { X = 3, Z = 0 } })).toBe(false)
		expect(Smash.canRestore({ x = 0, z = 0, radius = 5 }, { { X = 9, Z = 0 } })).toBe(true)
	end)
end)
```
(Smash는 Config를 require하지 않고 `Smash.setConfig(Config.SMASH)` — 기존 Logic 규칙.)

- [ ] **Step 2:** `luau tests/run.luau` → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** `/home/claude/check.sh` → `0 failed`
- [ ] **Step 5:** 커밋 `feat(smash): 건물 부수기 판정·보상 계산`

### Task 3: 맵 — 건물을 Breakable 모델로

**Files:** Modify `tools/osm/zone1.py`, `tools/genmap.py` (Model 노드 지원), `tools/map_check.py`; Test `tests/py/test_osm_zone1.py`

**Interfaces:**
- Produces: Buildings 그룹의 자식이 건물마다 `Model` `Building_<way id>` (자식 = 기존 파트들), 태그 `Breakable`, 속성 `Floors`(int), `HeightCm`(=Floors×300), `Zone`=1. 오스타(way 1092262563, 또는 zone1이 쓰는 ostar_w) 모델엔 `Ostar_*` 랜드마크 파트도 포함(Landmarks 그룹에서 이동). 2~4구역 건물은 이번 범위 밖(태그 없음).

- [ ] **Step 1: 실패하는 테스트**

```python
def test_buildings_are_breakable_models(model):
    blds = [n for n in walk(model) if n.get("name", "").startswith("Building_")]
    assert len(blds) > 500
    for b in blds:
        assert b["className"] == "Model"
        assert "Breakable" in b["properties"].get("Tags", [])
        a = b["attributes"]
        assert a["HeightCm"] == a["Floors"] * 300 and a["Floors"] >= 1
    ostar = [b for b in blds if any(c["name"].startswith("Ostar_") for c in b.get("children", []))]
    assert len(ostar) == 1 and ostar[0]["attributes"]["Floors"] == 38
    lm_tags = [n for n in walk(model) if n.get("name", "").startswith(("Station_", "BusStopA_", "Market_", "Roundabout_"))
               and "Breakable" in n.get("properties", {}).get("Tags", [])]
    assert not lm_tags
```
(`walk`가 없으면 같은 파일에 노드 순회 헬퍼 추가.)

- [ ] **Step 2:** `python3 -m pytest tests/py -q` → FAIL
- [ ] **Step 3:** 구현 (genmap의 노드→model.json 변환에 `Model` className 지원)
- [ ] **Step 4:** `python3 tools/genmap.py && python3 -m pytest tests/py -q && /home/claude/check.sh` → 모두 통과
- [ ] **Step 5:** 맵 빌드 후 커밋 `feat(map): 건물을 부술 수 있는 모델로 묶기`

### Task 4: BuildingService — 부수기·돌무더기·복구

**Files:** Create `src/server/Services/BuildingService.luau`; Modify `src/server/init.server.luau` (MonsterService 뒤)

**Interfaces:**
- Consumes: `Smash`, `Config.SMASH`, `HeightService.get/add/currentZone`, `Zones.bestGain`, `Growth.heightToScale`, CollectionService `Breakable`, 리모트 `Stomp`(기존, 두 번째 연결)
- Produces:
  - 모듈 맨 위에서 `Remotes.get("BuildingBroken")` (서버→모든 클라: `(cframe: CFrame, size: Vector3, color: Color3)`)
  - 시작 시 Breakable 모델마다 중심(x,z)·반지름(GetBoundingBox 수평 절반 대각)·`HeightCm`·`Floors` 색인
  - 부수기: 파트별 원래 `Transparency/CanCollide/CanQuery`를 속성 `_T/_C/_Q`로 저장 후 숨김, SurfaceGui `Enabled=false`, 바닥 돌무더기 3조각(`workspace.Rubble`), `BuildingBroken:FireAllClients`, 보상 `HeightService.add(player, Smash.reward(...), "smash")`, `Remotes.sfx(player, "bossHit")`
  - 복구: `respawn` 뒤 `Smash.canRestore` 실패면 `restoreRetry`초마다 재시도, 성공 시 원래 값 복구·돌무더기 삭제
  - 안내: 키 모자란 건물이 있으면 `Remotes.notify(player, "건물 Nm — 키가 더 커야 해요!")`, 플레이어당 `hintCooldown`
  - 쿨타임 `Config.SMASH.cooldown`, PlayerRemoving 정리

- [ ] **Step 1:** 구현 → **Step 2:** `/home/claude/check.sh` → `0 failed`, `build ok`, 경고 0 → **Step 3:** 커밋 `feat(smash): 건물 부수기 서버`

### Task 5: SmashFx — 잔해 연출

**Files:** Create `src/client/SmashFx.luau`; Modify 클라이언트 시작 목록(`src/client/init.client.luau`)

**Interfaces:**
- Consumes: `BuildingBroken(cframe, size, color)`
- Produces: 잔해 8조각(크기 = 건물 크기/6, 위로 튀었다 떨어짐, 클라이언트 물리, 2초 뒤 삭제), 먼지(ParticleEmitter 0.5초 방출), 가까우면 화면 흔들림(SoundFx의 shake가 노출되어 있으면 사용, 아니면 생략)

- [ ] **Step 1:** 구현 → **Step 2:** `/home/claude/check.sh` 통과 → **Step 3:** 커밋 `feat(smash): 무너지는 연출`

### Task 6: 생김새로 알아보는 가게

**Files:** Modify `tools/osm/buildings.py` (`_shop`: 글씨 간판 → 종류별 장식, 세로 간판 제거, 위층 색 창), `tools/osm/landmarks.py` (시장 아케이드 ShopSign → 물건 장식); Test `tests/py/test_osm_buildings.py`, `tests/py/test_osm_zone1.py`

**Interfaces:**
- Produces: `SHOP_TYPES = ["karaoke", "pcbang", "cafe", "chicken", "mart", "pharmacy", "salon", "snack", "academy", "flower"]`, 1층 칸마다 `rnd`로 종류 선택, 종류별 장식 함수 `_deco_<type>(F, sf, along, uw, parts, rich: bool)`. 유리 = 벽에서 1.6 앞, `transparency 0.45`. `rich=False`(작은 칸 uw<9 또는 예산 조정용)면 장식 2개 이하.

- [ ] **Step 1: 실패하는 테스트**

```python
def test_shop_has_no_text_and_has_deco():
    w = Way(11, {"building": "yes"}, [(0, 0), (30, 0), (30, 14), (0, 14), (0, 0)], True)
    parts = building_parts(w, {"street": (15, -20), "downtown": True})
    assert not any("label" in p for p in parts)
    assert any(p["name"].startswith("Deco") for p in parts)

def test_zone1_budget_and_no_building_text(model):  # test_osm_zone1.py
    assert part_count(model, zone=1) <= 15000
    for b in walk(model):
        if b.get("name", "").startswith("Building_"):
            for c in b.get("children", []):
                assert not c.get("children") or c["name"].startswith("Ostar_"), c["name"]  # SurfaceGui 자식 없음
```
- [ ] **Step 2:** `python3 -m pytest tests/py -q` → FAIL
- [ ] **Step 3:** 구현 (예산 넘으면 rich 조건을 좁혀 15,000 안으로; 13,000 예산 테스트는 15,000으로)
- [ ] **Step 4:** `python3 tools/genmap.py && python3 -m pytest tests/py -q && /home/claude/check.sh` 통과
- [ ] **Step 5:** 미리보기 1장(상가 거리)으로 생김새 확인 → 커밋 `feat(map): 글씨 대신 생김새로 알아보는 가게`

### Task 7: Studio 플레이 테스트와 문서

**Files:** Modify `docs/PLAYTEST.md` (22번: 10cm·부수기·가게), `README.md`

- [ ] **Step 1:** (사용자 Pull + 새 BaseMap 넣은 뒤) MCP 플레이: 콘솔 에러 없음, 새 플레이어 10cm·작은 몸
- [ ] **Step 2:** MCP Server `execute_luau`: 테스트 플레이어 키를 2,000cm로 → 2층 건물 옆 착지 시뮬레이션(BuildingService 내부 break 호출 또는 Stomp 처리) → 숨김·돌무더기·보상, 61초 뒤 복구 확인, 15층 아파트는 안내만
- [ ] **Step 3:** 상가 거리 스크린샷으로 가게 생김새 확인
- [ ] **Step 4:** 문서 갱신, `/home/claude/check.sh` 통과, 커밋·푸시
