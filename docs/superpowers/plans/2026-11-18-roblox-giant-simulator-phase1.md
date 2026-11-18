# 거인 키 키우기 1차(기본판) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 친구들이 같은 서버에서 맵을 돌아다니며 키를 키우고(음식·우유 비·농구·철봉·침대), 키만큼 아바타가 실제로 커지고, 키 조건 문으로 3개 구역이 열리고, 키가 저장되고 리더보드로 겨루는 로블록스 게임 기본판.

**Architecture:** 서버가 키의 유일한 주인(서버 권한). 숫자 계산은 로블록스 API를 쓰지 않는 순수 모듈(`src/shared/Logic`)에 모아 워크스페이스에서 `luau` CLI로 테스트한다. 시설은 CollectionService 태그로 찾기 때문에, 서준이가 스튜디오에서 맵을 마음대로 옮기고 꾸며도 코드가 깨지지 않는다. Rojo는 스크립트만 동기화하고, 기본 맵은 한 번만 넣는 `.rbxm` 파일로 따로 준다.

**Tech Stack:** Roblox Studio, Luau, Rojo 7 (VS Code 확장 + Studio 플러그인), DataStoreService, OrderedDataStore, CollectionService, GitHub (flossseojun), 테스트용 `luau` CLI (luau-lang/luau 릴리스)

**Spec:** `docs/superpowers/specs/2026-11-18-roblox-giant-simulator-design.md`

## Global Constraints

- 시작 키 150cm, 화면 표시는 cm (100,000cm 이상은 m/km 단위로 줄여 표시)
- 몸 크기는 키에 로그 비례, 상한 있음
- 구역 3개: ① 동네 놀이터 ② 학교 운동장 ③ 구름 위
- 화면 글자는 모두 한국어
- 폰에서도 모든 조작 가능(터치 버튼)
- 키는 서버만 바꾼다. 클라이언트가 보낸 숫자를 키에 그대로 더하지 않는다
- 유료 아이템·거래·플레이어끼리 대결 없음
- 1차 범위 밖: 펫, 구역 보스, 하이파이브 (2차 계획에서 다룸)
- Claude는 로블록스를 실행할 수 없음 → 로블록스 쪽 확인은 매 태스크 끝 "스튜디오 확인" 체크리스트로 서준이가 함

## 숫자 (Config에 그대로 들어갈 초기값, 밸런스는 테스트하며 조정)

| 항목 | 값 |
|---|---|
| 몸 크기 | `scale = min(12, 1 + 1.5 * log10(height / 150))`, height < 150이면 1 |
| 구역 키 조건 | 1구역 0cm, 2구역 1,000cm, 3구역 100,000cm |
| 1구역 음식 | 멸치 +1, 우유 +2, 계란 +3 |
| 2구역 음식 | 두유 +15, 치즈 +20, 닭가슴살 +30 |
| 3구역 음식 | 별사탕 +200, 구름우유 +300, 무지개 계란 +500 |
| 황금 우유 | 확률 2%, 그 구역 가장 좋은 음식 × 10 |
| 음식 재생성 | 스폰 지점마다 먹힌 뒤 8초 |
| 우유 비 | 180초마다, 10초 전 알림, 우유 30개, 개당 그 구역 최고 음식 × 3, 20초 뒤 사라짐 |
| 농구 | 골 1번 = 그 구역 최고 음식 × 5, 같은 사람 골 쿨다운 2초 |
| 철봉 | 초당 연타 4회 이상이면 매초 그 구역 최고 음식 × 1, 미만이면 떨어짐. 연타 서버 인정 상한 초당 12회 |
| 침대 | 5초마다 그 구역 최고 음식 × 0.5 |
| 걷기/점프 | `WalkSpeed = 16 * sqrt(scale)`, `JumpPower = 50 * sqrt(scale)` |
| 카메라 | `MaxZoomDistance = 30 * scale` |

## Review Focus

1. **나갈 때·서버 꺼질 때 저장 누락** → `PlayerRemoving`과 `game:BindToClose`에서 모두 저장해야 함 (Task 3 스튜디오 확인에 포함)
2. **DataStore 불러오기 실패 시 기본값으로 덮어쓰기** → 불러오기에 실패한 플레이어는 저장하지 않음 (Task 3 테스트 `loadFailedBlocksSave`)
3. **두 명이 같은 음식을 동시에 먹음** → 한 명만 받음 (Task 5 `FoodSpawner` 테스트 `claimOnce`)
4. **연타 매크로/조작된 RemoteEvent** → 서버가 초당 12회 넘는 입력을 버림 (Task 8 테스트 `capsMashRate`)
5. **키가 엄청 커졌을 때 물리·카메라 깨짐** → 크기 상한 12, 스케일 변화 0.02 미만이면 다시 적용하지 않음 (Task 2 테스트 `scaleCapped`, Task 3 확인)

---

## 파일 구조

```
giant-height-roblox/
  default.project.json        # 스크립트만 동기화
  map.project.json            # 기본 맵 → build/BaseMap.rbxm
  docs/SETUP.md               # 서준이용 설치 안내 (한국어)
  docs/PLAYTEST.md            # 태스크별 스튜디오 확인 체크리스트 누적
  src/shared/Config.luau      # 위 숫자 표 전부
  src/shared/Logic/Growth.luau
  src/shared/Logic/Zones.luau
  src/shared/Logic/FoodSpawner.luau
  src/shared/Logic/MilkRain.luau
  src/shared/Logic/BarMash.luau
  src/shared/Logic/Format.luau
  src/server/init.server.luau          # 서비스 시작
  src/server/Services/DataService.luau
  src/server/Services/HeightService.luau
  src/server/Services/FoodService.luau
  src/server/Services/ZoneService.luau
  src/server/Services/MilkRainService.luau
  src/server/Services/BasketballService.luau
  src/server/Services/BarService.luau
  src/server/Services/BedService.luau
  src/server/Services/LeaderboardService.luau
  src/client/init.client.luau          # HUD, 알림, 카메라, 철봉 버튼
  map/BaseMap/...                      # .model.json 파트들
  tests/run.luau                       # 아주 작은 테스트 러너
  tests/*.spec.luau
```

**순수 모듈 규칙:** `src/shared/Logic/*`는 `game`, `Instance`, `workspace` 등 로블록스 전역을 쓰지 않고 서로 require하지 않는다. 필요한 Config 값은 인자로 받는다. 그래야 `luau` CLI에서 `require("../src/shared/Logic/Growth")`로 테스트되고, 로블록스에서도 `require(ReplicatedStorage.Shared.Logic.Growth)`로 그대로 쓰인다.

**태그 규칙 (맵 ↔ 코드 약속):**

| 태그 | 붙는 곳 | Attribute |
|---|---|---|
| `FoodSpawn` | 음식 생기는 지점(투명 파트) | `Zone: number` |
| `ZoneGate` | 구역 문 | `Zone: number` |
| `ZoneArea` | 구역 바닥 영역(투명, CanCollide false) | `Zone: number` |
| `MilkRainSpot` | 우유 비 내리는 중심 | `Zone: number` |
| `Hoop` | 골대 링 아래 센서 | `Zone: number` |
| `BallRack` | 공 받는 곳 | `Zone: number` |
| `Bar` | 철봉 | `Zone: number` |
| `Bed` | 침대 | `Zone: number` |
| `GlobalBoard` | 역대 순위판 SurfaceGui 붙일 파트 | 없음 |

---

### Task 1: 저장소·Rojo·테스트 환경 + 서준이 설치 안내

**Files:**
- Create: `default.project.json`, `src/shared/Config.luau`, `src/server/init.server.luau`, `src/client/init.client.luau`, `tests/run.luau`, `tests/config.spec.luau`, `docs/SETUP.md`, `docs/PLAYTEST.md`, `.gitignore`, `README.md`

**Interfaces:**
- Produces: `Config` 테이블 — `START_HEIGHT=150`, `MAX_SCALE=12`, `SCALE_K=1.5`, `ZONES = { {id=1,name="동네 놀이터",minHeight=0,foods={...}}, {id=2,name="학교 운동장",minHeight=1000,...}, {id=3,name="구름 위",minHeight=100000,...} }`, 음식은 `{id: string, name: string, gain: number}`, `GOLDEN_CHANCE=0.02`, `GOLDEN_MULT=10`, `FOOD_RESPAWN=8`, `RAIN={interval=180,warn=10,count=30,mult=3,life=20}`, `HOOP={mult=5,cooldown=2}`, `BAR={minRate=4,maxRate=12}`, `BED={period=5,mult=0.5}`
- Produces: `tests/run.luau` — `describe(name, fn)`, `it(name, fn)`, `expect(v).toBe(x)`, `expect(v).toBeCloseTo(x, eps)`, 실패 시 종료 코드 1
- Rojo 매핑: `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayer.StarterPlayerScripts.Client`

- [ ] **Step 1 (서준이):** GitHub에서 빈 저장소 `flossseojun/giant-height-roblox` 만들기 → Claude가 push 권한으로 연결
- [ ] **Step 2:** 워크스페이스에 `luau` CLI 설치 (luau-lang/luau GitHub 릴리스 linux zip), `luau --version` 확인
- [ ] **Step 3: 실패하는 테스트** `tests/config.spec.luau` — `it("zones ascend")`: `Config.ZONES[2].minHeight == 1000`, `Config.ZONES[3].minHeight == 100000`, 각 구역 foods 3개, 각 구역 최고 음식 gain이 2/30/500
- [ ] **Step 4:** `luau tests/run.luau` → FAIL (Config 없음)
- [ ] **Step 5:** `Config.luau`, `run.luau` 작성 → PASS
- [ ] **Step 6:** 빈 `init.server.luau`(print "서버 시작"), `init.client.luau`(print "클라 시작"), `default.project.json`
- [ ] **Step 7:** `docs/SETUP.md` (한국어, 스크린샷 없이 단계별): 로블록스 스튜디오 설치 → VS Code 설치 → Git으로 저장소 클론 → VS Code에서 "Rojo" 확장 설치 → 확장이 Rojo 설치 → 스튜디오 Rojo 플러그인 설치 → VS Code에서 `default.project.json`으로 서버 시작 → 스튜디오 플러그인 Connect → Output에 "서버 시작" 확인. 이후 업데이트 받는 법: `git pull`만 하면 스튜디오에 자동 반영
- [ ] **Step 8:** 커밋·push. **스튜디오 확인:** 서준이가 SETUP.md대로 연결 후 플레이 → Output에 "서버 시작", "클라 시작"

### Task 2: 성장·구역·표시 순수 로직

**Files:**
- Create: `src/shared/Logic/Growth.luau`, `src/shared/Logic/Zones.luau`, `src/shared/Logic/Format.luau`
- Test: `tests/growth.spec.luau`, `tests/zones.spec.luau`, `tests/format.spec.luau`

**Interfaces:**
- Produces: `Growth.heightToScale(height: number, k: number, maxScale: number): number`
- Produces: `Growth.shouldRescale(oldScale: number, newScale: number): boolean` (차이 ≥ 0.02)
- Produces: `Growth.moveStats(scale: number): {walkSpeed: number, jumpPower: number, maxZoom: number}`
- Produces: `Zones.highestUnlocked(height: number, zones): number`, `Zones.canEnter(height: number, zone): boolean`, `Zones.bestGain(zone): number`
- Produces: `Format.height(cm: number): string`

- [ ] **Step 1: 실패하는 테스트**
  - `heightToScale(150,1.5,12)` → 1; `(100,…)` → 1; `(1500,…)` → 2.5; `(15000,…)` ≈ 4; `scaleCapped`: `(1e30,…)` → 12
  - `shouldRescale(2.0, 2.01)` → false; `(2.0, 2.03)` → true
  - `moveStats(4)` → walkSpeed 32, jumpPower 100, maxZoom 120
  - `highestUnlocked(999, Z)` → 1; `(1000, Z)` → 2; `(100000, Z)` → 3
  - `Format.height(1234)` → `"1,234cm"`; `(250000)` → `"2.5km"`; `(150000)` → `"1.5km"`; `(99999)` → `"99,999cm"`
- [ ] **Step 2:** `luau tests/run.luau` → FAIL
- [ ] **Step 3:** 구현 (공식은 숫자 표 그대로)
- [ ] **Step 4:** PASS
- [ ] **Step 5:** 커밋

### Task 3: 키 저장·적용 (DataService + HeightService) + HUD

**Files:**
- Create: `src/server/Services/DataService.luau`, `src/server/Services/HeightService.luau`
- Modify: `src/server/init.server.luau`, `src/client/init.client.luau`
- Create: `src/shared/Logic/SaveGuard.luau`, Test: `tests/saveguard.spec.luau`

**Interfaces:**
- Consumes: `Growth.*`, `Zones.*`, `Format.height`
- Produces: `DataService.load(player): (boolean, {height: number})`, `DataService.save(player)`; DataStore 이름 `"GiantHeight_v1"`, 키 `"u_" .. userId`
- Produces: `HeightService.get(player): number`, `HeightService.add(player, amount: number, source: string)` — 키를 더하고, leaderstats `키`(StringValue, Format) 갱신, 플레이어 Attribute `Height`(number) 갱신, 필요하면 캐릭터 `Model:ScaleTo(scale)` + Humanoid WalkSpeed/JumpPower(UseJumpPower=true) 적용
- Produces: `HeightService.currentZone(player): number` (Attribute `Zone`, ZoneService가 설정; 기본 1)
- Produces: `ReplicatedStorage.Remotes` 폴더 (이후 태스크가 RemoteEvent를 여기에 만듦), RemoteEvent `Notify(text: string)`
- Produces: `SaveGuard.new() → {markLoaded(ok: boolean), canSave(): boolean}`

- [ ] **Step 1: 실패하는 테스트** `loadFailedBlocksSave`: `markLoaded(false)` 후 `canSave()` → false; `markLoaded(true)` 후 → true; 처음 상태 → false
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS
- [ ] **Step 5:** DataService: `GetAsync`를 3번까지 재시도, 실패 시 플레이어에게 Notify("저장 불러오기 실패 — 이번 판 기록은 저장되지 않아요"); `PlayerRemoving`, `BindToClose`, 60초 자동 저장에서 `canSave()`일 때만 `UpdateAsync`
- [ ] **Step 6:** HeightService: `CharacterAdded`마다 크기·속도 다시 적용
- [ ] **Step 7:** 클라이언트: 화면 위 가운데 큰 키 표시(`Height` Attribute 변화 감지, Format), Notify 토스트, 카메라 MaxZoomDistance를 `moveStats`로 조정
- [ ] **Step 8:** 테스트용 임시 명령: 스튜디오에서만(`RunService:IsStudio()`) 채팅 `/grow 10000` → `HeightService.add`
- [ ] **Step 9:** 커밋. **스튜디오 확인 (PLAYTEST.md에 추가):** `/grow 1000`, `/grow 100000`, `/grow 1e12`로 몸이 커지고 상한에서 멈추는지, 걷기·점프·카메라가 자연스러운지, 리셋해도 크기 유지, 게임 Publish + "API 서비스 접근 허용" 켠 뒤 나갔다 들어와도 키 유지

### Task 4: 기본 맵 (BaseMap.rbxm)

**Files:**
- Create: `map.project.json`, `map/BaseMap/**.model.json`

**Interfaces:**
- Produces: 위 "태그 규칙" 표의 태그·Attribute가 붙은 파트들. 구역 1(원점, 200×200 스터드), 구역 2(1구역 옆, 문 높이 30스터드), 구역 3(공중 섬, 2구역에서 오르는 큰 계단 — 3구역 키여야 계단 한 칸을 오를 수 있는 높이). 구역당 `FoodSpawn` 20개, `MilkRainSpot` 1개, `Hoop`+`BallRack` 1세트, `Bar` 1개, `Bed` 2개. 스폰 지점은 1구역. `GlobalBoard` 1개는 스폰 근처
- 색은 구역별로 구분(놀이터 연두, 운동장 주황 흙, 구름 흰색·하늘색), 꾸미기는 서준이 몫

- [ ] **Step 1:** `rojo build map.project.json -o build/BaseMap.rbxm` 성공 확인 (워크스페이스에 rojo 설치)
- [ ] **Step 2:** 태그 개수 검사 스크립트(`tests/map_check.luau` 또는 model.json을 읽는 간단한 검사): 구역별 FoodSpawn 20, 나머지 표 개수 일치
- [ ] **Step 3:** 커밋, `BaseMap.rbxm`을 서준이에게 파일로 전달. **스튜디오 확인:** Workspace에 끌어다 넣기(한 번만), 세 구역이 보이고 스폰이 1구역

### Task 5: 성장 음식 (FoodService)

**Files:**
- Create: `src/shared/Logic/FoodSpawner.luau`, `src/server/Services/FoodService.luau`
- Test: `tests/food.spec.luau`

**Interfaces:**
- Consumes: `Config.ZONES`, `HeightService.add`, 태그 `FoodSpawn`
- Produces: `FoodSpawner.pick(zone, rand: number): {id, name, gain, golden: boolean}` (rand는 0~1; `rand < GOLDEN_CHANCE`면 황금 우유, 아니면 구역 음식 3개 중 균등)
- Produces: `FoodSpawner.newSlot() → {claim(): boolean, reset()}` (`claimOnce`: 첫 claim만 true)

- [ ] **Step 1: 실패하는 테스트** — `pick(Z1, 0.01)` → golden, gain 30; `pick(Z2, 0.5)` → golden false, id ∈ 2구역 음식; `claimOnce`: claim() true, claim() false, reset() 후 true
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS
- [ ] **Step 5:** FoodService: 각 `FoodSpawn`에 음식 파트(구역 색·이름표 BillboardGui, 황금은 반짝이는 금색) 생성, Touched → 캐릭터 주인 확인 → `slot.claim()` → `HeightService.add` + 머리 위 "+N cm" 표시 → 8초 뒤 재생성. 음식 크기는 먹는 사람이 커도 닿게 Touched 영역을 넉넉히
- [ ] **Step 6:** 커밋. **스튜디오 확인:** 음식 먹으면 키 증가, 2인 테스트(스튜디오 "Test → 2 Players")로 같은 음식 동시 접근 시 한 명만 받음

### Task 6: 구역 문 (ZoneService)

**Files:**
- Create: `src/server/Services/ZoneService.luau`
- Modify: `src/client/init.client.luau`

**Interfaces:**
- Consumes: `Zones.canEnter`, `Zones.highestUnlocked`, 태그 `ZoneGate`, `ZoneArea`
- Produces: 플레이어 Attribute `Zone` (현재 서 있는 구역)

- [ ] **Step 1:** 클라이언트: 자기 키로 열린 `ZoneGate`는 로컬에서 `CanCollide=false`·반투명, 아니면 문에 "키 10m 필요" 표시
- [ ] **Step 2:** 서버: 0.5초마다 캐릭터 위치가 어느 `ZoneArea` 안인지 계산해 `Zone` 설정, 자격 없는 구역이면 이전 구역 스폰 쪽으로 되돌림 + Notify("아직 키가 부족해요! ○○ 필요")
- [ ] **Step 3:** 처음 열린 구역에 들어가면 서버 전체 Notify("○○님이 학교 운동장에 입장!")
- [ ] **Step 4:** 커밋. **스튜디오 확인:** `/grow`로 조건 넘기 전엔 못 지나가고, 넘으면 통과, 문 우회(점프로 넘기)해도 되돌려짐

### Task 7: 우유 비 (MilkRainService)

**Files:**
- Create: `src/shared/Logic/MilkRain.luau`, `src/server/Services/MilkRainService.luau`
- Test: `tests/milkrain.spec.luau`

**Interfaces:**
- Consumes: `Config.RAIN`, `FoodSpawner.newSlot`, `HeightService.add`, 태그 `MilkRainSpot`
- Produces: `MilkRain.phase(elapsed: number, interval: number, warn: number): "idle" | "warning" | "raining"` (주기 안 위치로 판단: `interval-warn ≤ t < interval` warning, 주기 시작 직후 0~1초 raining 트리거)
- Produces: `MilkRain.dropGain(zone, mult): number`

- [ ] **Step 1: 실패하는 테스트** — `phase(100,180,10)` idle; `phase(175,180,10)` warning; `phase(180.5,180,10)` raining; `dropGain(Z1,3)` → 9
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS
- [ ] **Step 5:** 서비스: 경고 때 서버 전체 Notify("10초 뒤 ○○에 우유 비가 내려요!") — 장소는 `MilkRainSpot` 중 무작위, 비는 하늘에서 우유 30개가 떨어지고(물리 낙하) 한 개씩 한 명만, 20초 뒤 남은 건 제거
- [ ] **Step 6:** 커밋. **스튜디오 확인:** Config의 interval을 임시로 30으로 줄여 알림→비→먹기→사라짐 확인 후 되돌리기

### Task 8: 철봉 (BarService)

**Files:**
- Create: `src/shared/Logic/BarMash.luau`, `src/server/Services/BarService.luau`
- Modify: `src/client/init.client.luau`
- Test: `tests/barmash.spec.luau`

**Interfaces:**
- Consumes: `Config.BAR`, `Zones.bestGain`, `HeightService.add`, 태그 `Bar`
- Produces: RemoteEvent `BarMash` (클라→서버, 인자 없음), RemoteEvent `BarState(active: boolean)` (서버→클라)
- Produces: `BarMash.new(minRate, maxRate) → {press(t: number), tick(t: number): "hold" | "fall"}` — 최근 1초 창의 입력 수 기준; 창 안에서 maxRate를 넘는 입력은 버림

- [ ] **Step 1: 실패하는 테스트** — 1초에 5번 press 후 `tick` → "hold"; 3번이면 "fall"; `capsMashRate`: 1초에 50번 press해도 창 안 카운트 12
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS
- [ ] **Step 5:** 서버: `Bar`의 ProximityPrompt "매달리기" → 캐릭터를 철봉에 고정(Anchored 또는 AlignPosition), `BarState(true)`; 매초 tick, hold면 `bestGain × 1` 추가, fall이면 내려놓고 `BarState(false)`; 플레이어 퇴장·사망 시 정리
- [ ] **Step 6:** 클라: 매달리는 동안 화면 아래 큰 "연타!" 버튼(폰) + 스페이스바(PC) → `BarMash:FireServer()`, 남은 힘 게이지 표시
- [ ] **Step 7:** 커밋. **스튜디오 확인:** PC 스페이스 연타·폰 에뮬레이터(스튜디오 Device 에뮬레이션) 버튼 연타로 버티기/떨어지기, 매달린 채 나가도 오류 없음

### Task 9: 농구 골대 (BasketballService)

**Files:**
- Create: `src/server/Services/BasketballService.luau`

**Interfaces:**
- Consumes: `Config.HOOP`, `Zones.bestGain`, `HeightService.add`, 태그 `Hoop`, `BallRack`
- 공은 서버가 만든 파트, Attribute `Owner = userId`

- [ ] **Step 1:** `BallRack`의 ProximityPrompt "공 받기" → 공을 손에 붙임(Weld), 한 사람당 공 1개
- [ ] **Step 2:** 던지기: 클라이언트에서 화면 탭/클릭한 방향을 RemoteEvent `ThrowBall(direction: Vector3)`으로 보냄 → 서버가 방향을 단위벡터로 정규화하고 힘은 서버가 정한 값(키에 비례)으로 공 발사. 클라 값은 방향만 사용
- [ ] **Step 3:** `Hoop` 센서에 공이 위에서 아래로 통과(속도 Y < 0)하면 Owner에게 `bestGain × 5`, 쿨다운 2초, "골!" 효과. 10초 지나면 공 사라지고 다시 받을 수 있음
- [ ] **Step 4:** 커밋. **스튜디오 확인:** 키 작을 땐 넣기 어렵고 클수록 쉬운지, 남의 공으로 골 넣어도 보상은 공 주인에게만, 폰 탭 던지기

### Task 10: 침대 (BedService)

**Files:**
- Create: `src/server/Services/BedService.luau`

**Interfaces:**
- Consumes: `Config.BED`, `Zones.bestGain`, `HeightService.add`, 태그 `Bed`

- [ ] **Step 1:** ProximityPrompt "자기" → 캐릭터 눕히기(Seat 또는 고정), 한 침대 한 명, 머리 위 "Zzz"
- [ ] **Step 2:** 5초마다 `bestGain × 0.5`, 움직이면(점프 입력) 일어남
- [ ] **Step 3:** 커밋. **스튜디오 확인:** 누워 있는 동안 키가 오르고, 두 명이 같은 침대 못 씀, 자다가 나가도 침대가 비워짐

### Task 11: 리더보드 (LeaderboardService)

**Files:**
- Create: `src/server/Services/LeaderboardService.luau`

**Interfaces:**
- Consumes: `HeightService.get`, `Format.height`, 태그 `GlobalBoard`
- OrderedDataStore 이름 `"GiantHeight_Top_v1"`, 값은 `math.floor(height)` (정수 필요, 10^15 넘으면 10^15로 자름)

- [ ] **Step 1:** 서버 안 순위는 Task 3의 leaderstats로 이미 됨 → 머리 위에 이름+키 BillboardGui 추가
- [ ] **Step 2:** 60초마다 접속자 키를 OrderedDataStore에 `SetAsync`, `GetSortedAsync(false, 10)`로 상위 10명을 `GlobalBoard`의 SurfaceGui에 "1위 이름 — 키"로 표시 (이름은 `Players:GetNameFromUserIdAsync`, pcall)
- [ ] **Step 3:** 커밋. **스튜디오 확인:** Publish한 게임에서 보드에 내 이름이 1분 안에 뜸

### Task 12: 마무리 플레이테스트

**Files:**
- Modify: `docs/PLAYTEST.md`, `src/shared/Config.luau`(밸런스 조정)

- [ ] **Step 1:** `luau tests/run.luau` 전부 PASS
- [ ] **Step 2:** 스튜디오에서 `/grow` 명령이 실제 서버에선 안 되는지 확인(IsStudio 조건)
- [ ] **Step 3 (서준이):** Publish → 폰 로블록스 앱으로 접속, 친구 1~2명과 15분 플레이. PLAYTEST.md 전체 체크
- [ ] **Step 4:** 피드백으로 Config 숫자 조정, 커밋, 2차(펫·보스·하이파이브) 설계로 넘어감
