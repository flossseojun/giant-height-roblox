# 실제 양평역 1구역 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** OpenStreetMap 실제 데이터로 양평역 주변(역 중심 ±560m × ±520m)을 1구역으로 자동 생성하고, 랜드마크(양평역·정류장 A·로터리·오스타 코아루·물맑은시장)는 스튜디오 MCP로 상세 제작해 기존 게임 기능이 그대로 동작하게 한다.

**Architecture:** `tools/osm/` 파이썬 패키지가 저장된 OSM 추출(`data/yangpyeong_station.osm`)을 읽어 스터드 좌표로 투영하고 건물·도로·철로·하천을 파트/지형 명령으로 바꾼다. `tools/genmap.py`가 이 결과로 1구역을 만들고(2~4구역은 서쪽으로 이동), 지형(물)은 스튜디오에서 실행할 Luau 파일로 따로 출력한다. 랜드마크와 지형·조명은 MCP `execute_luau`로 스튜디오에 적용하고 같은 코드를 `tools/studio/`에 보관한다.

**Tech Stack:** Python 3 (xml.etree, math, pytest), Rojo 7.6.1 `rojo build`, Roblox Studio 내장 MCP (`execute_luau`, `screen_capture`, `start_stop_play`), 기존 Luau 게임 코드

**Spec:** `docs/superpowers/specs/2026-11-19-real-yangpyeong-station-design.md`

## Global Constraints

- 기준점(원점) = 양평역 37.49285N, 127.49190E. +X = 동쪽, **−Z = 북쪽**, 바닥 윗면 y = 0
- 축척: 가로·세로 1m = 1.6 스터드, 1층 = 7 스터드
- 범위: OSM bbox 127.4855~127.4985, 37.4880~37.4975
- 1구역 파트 수 ≤ 8,000
- 지도에 없는 랜드마크를 지어내지 않는다. 도로·철로·하천 방향은 OSM 그대로
- 스폰: 정류장 A 앞에서 양평역을 바라봄. 정류장 A = 역전길 북쪽, 오스타 코아루 맞은편. 역 기준 동쪽 −112m, 북쪽 −48m → 스터드 약 (−179, 0, +77) (북쪽이 −Z라 남쪽은 +Z). Task 1 투영으로 확정
- 게임 태그(FoodSpawn, ZoneArea, ZoneGate, Hoop, BallRack, Bar, Bed, MilkRainSpot, BossSpawn, GlobalBoard, WeeklyBoard, StarPoint)와 개수 규칙 유지. 1구역 FoodSpawn은 60개
- 출처 표기 "© OpenStreetMap contributors" — README와 게임 안 안내판
- 2구역 문은 1구역 서쪽 큰길 끝. 2·3·4구역은 디자인 그대로 서쪽으로 이동, ZoneArea끼리 겹치지 않음

## Review Focus

1. **음식이 건물 안에 생김** → FoodSpawn은 도로·인도·광장 위에만, 건물 윤곽과 겹치면 제외 (Task 6 테스트 `food_not_in_buildings`)
2. **ZoneArea 겹침으로 1구역에서 다른 구역 판정** → 모든 ZoneArea 쌍의 XZ 겹침 없음 (Task 6 `zone_areas_disjoint`)
3. **파트 수 초과로 폰 끊김** → 1구역 ≤ 8,000 (Task 6 `part_budget`)
4. **복잡한 건물 윤곽이 깨짐(자기교차·중복점)** → 삼각분할 실패 시 회전 상자로 대체, 예외 없이 진행 (Task 2 `degenerate_polygon_falls_back`)
5. **스폰에서 역이 안 보임** → 스크린샷으로 확인 (Task 8 확인 단계)

---

## 파일 구조

```
data/yangpyeong_station.osm          # OSM 추출 (커밋됨)
tools/osm/__init__.py
tools/osm/project.py                 # 위경도 → 스터드 투영, OSM 로드·분류
tools/osm/geom.py                    # 회전 사각형, 삼각분할, 쐐기 파트 변환
tools/osm/buildings.py               # 건물 → 파트
tools/osm/roads.py                   # 도로·인도·차선 → 파트
tools/osm/rail_water.py              # 고가 철로·승강장 → 파트, 하천 → 지형 Luau
tools/osm/zone1.py                   # 위 모두 묶어 1구역 폴더 + 게임 태그 + 출처 안내판
tools/genmap.py                      # town1 대신 zone1 사용, 2~4구역 이동
tools/map_check.py                   # 개수·겹침·예산 검사 추가
tools/studio/terrain_water.luau      # (생성물) 양근천·남한강 지형 물
tools/studio/landmarks/*.luau        # 스튜디오에서 실행한 랜드마크 코드 보관
tests/py/test_osm_*.py               # pytest
```

---

### Task 1: OSM 로드와 투영

**Files:** Create `tools/osm/__init__.py`, `tools/osm/project.py`, `tests/py/test_osm_project.py`

**Interfaces:**
- Produces: `ORIGIN = (37.49285, 127.49190)`, `SCALE = 1.6`, `FLOOR = 7`
- Produces: `to_studs(lat: float, lon: float) -> tuple[float, float]` (x, z), 북쪽이 −z
- Produces: `load(path: str) -> OsmData` — `OsmData.ways: list[Way]`, `Way(id: int, tags: dict, pts: list[tuple[float,float]], closed: bool)` (pts는 스터드 좌표)
- Produces: `classify(way) -> str` ∈ {"building","road","rail","platform","station","water","green","other"}

- [ ] **Step 1: 실패하는 테스트**
  - `to_studs(*ORIGIN) == (0, 0)`
  - 동쪽 100m 지점: x ≈ 160 (±0.5), z ≈ 0
  - 북쪽 100m 지점: z ≈ −160, x ≈ 0
  - `load("data/yangpyeong_station.osm")`: building 분류 ≥ 700개, station 분류 1개(그 중심이 원점에서 120스터드 이내), 이름 "현대성우오스타코아루아파트"인 way의 tags["building:levels"] == "38"
  - `classify`: waterway=stream → "water", highway=tertiary → "road", railway=platform → "platform", building=train_station → "station"
- [ ] **Step 2:** `python3 -m pytest tests/py/test_osm_project.py -q` → FAIL
- [ ] **Step 3:** 구현 (경도 1도 = 111320·cos(위도) m, 위도 1도 = 110540 m)
- [ ] **Step 4:** PASS
- [ ] **Step 5:** 커밋

### Task 2: 기하 도우미

**Files:** Create `tools/osm/geom.py`, `tests/py/test_osm_geom.py`

**Interfaces:**
- Produces: `min_rect(pts) -> (cx, cz, w, d, yaw)` — 최소 면적 회전 사각형 (yaw 라디안, Y축 회전)
- Produces: `rectangularity(pts) -> float` = 다각형 넓이 / min_rect 넓이
- Produces: `triangulate(pts) -> list[tuple[pt,pt,pt]]` (귀 자르기, 시계/반시계 모두 처리, 중복점 제거)
- Produces: `wedges(tri, y0, h) -> list[PartSpec]` — 삼각기둥 하나를 WedgePart 2개로
- Produces: `PartSpec = dict(cls, pos(x,y,z), size(x,y,z), rot(3x3 행우선))` — genmap `part()`가 받는 형식으로 변환할 수 있는 최소 정보

- [ ] **Step 1: 실패하는 테스트**
  - 10×4 직사각형을 30° 돌린 점들 → `min_rect` w,d = 10,4 (순서 무관, ±0.01), yaw ≡ 30° (mod 90°)
  - L자(넓이 3) → `rectangularity` ≈ 0.75, `triangulate` 넓이 합 = 3 (±1e-6)
  - `degenerate_polygon_falls_back`: 점 3개가 일직선 / 중복점만 있는 경우 `triangulate` == [] (예외 없음)
  - `wedges`: 직각삼각형 (0,0),(4,0),(0,3), h=7 → 쐐기 2개, 두 쐐기 size.y 모두 7, 밑면 넓이 합 = 6 (±1e-6)
- [ ] **Step 2:** FAIL → **Step 3:** 구현 (쐐기 분할은 삼각형 최장변에 수선을 내려 두 직각삼각형으로) → **Step 4:** PASS → **Step 5:** 커밋

### Task 3: 건물

**Files:** Create `tools/osm/buildings.py`, `tests/py/test_osm_buildings.py`

**Interfaces:**
- Consumes: Task 1 `Way`, Task 2 `min_rect`, `rectangularity`, `triangulate`, `wedges`
- Produces: `floors(tags: dict, way_id: int) -> int` — building:levels 우선, 없으면 apartments 15, commercial/retail 4, house/detached/residential 2, 그 외 2~3 (way_id로 고정 난수)
- Produces: `building_parts(way) -> list[PartSpec]` — 몸체 + 층마다 창문 띠(긴 두 면) + 지붕 테두리. rectangularity ≥ 0.85면 회전 상자 1개, 아니면 쐐기(삼각형 24개 넘거나 실패 시 회전 상자)
- Produces: `PALETTE` (외벽 6색, 창문 1색), 건물 ID로 색 고정

- [ ] **Step 1: 실패하는 테스트**
  - `floors({"building:levels":"38"}, 1) == 38`, `floors({"building":"house"}, 5) == 2`, `floors({"building":"apartments"},9) == 15`
  - `floors({"building":"yes"}, 777)` 두 번 호출 결과 같음, 2 또는 3
  - 오스타 코아루 way → 몸체 높이 266 (38×7)
  - 직사각 건물 → 몸체 파트 1개 (cls "Part")
  - L자 건물 → 몸체가 WedgePart들
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS → **Step 5:** 커밋

### Task 4: 도로

**Files:** Create `tools/osm/roads.py`, `tests/py/test_osm_roads.py`

**Interfaces:**
- Produces: `road_width_m(tags) -> float` — lanes 있으면 lanes×3.5, 없으면 secondary/tertiary 7, tertiary_link 6, residential/unclassified/living_street 5, service 3.5, footway/path/cycleway/steps/pedestrian 2.5
- Produces: `road_parts(way) -> list[PartSpec]` — 선분마다 회전 상자(두께 0.2, y=0.1), 꺾이는 점에 원기둥 이음(지름=폭). tertiary 이상은 중앙선(노랑)·인도(양쪽 2m) 추가. footway류는 인도 색
- Produces: `road_segments(ways) -> list[(x0,z0,x1,z1,width)]` (Task 6 음식 배치용)

- [ ] **Step 1: 실패하는 테스트**
  - `road_width_m({"highway":"tertiary","lanes":"4"}) == 14`, `({"highway":"service"}) == 3.5`
  - 길이 100스터드 동서 선분 → 상자 size.x(또는 z)=100, 폭 = 폭m×1.6
  - 4차선 역전길 way → 결과에 이름이 "CenterLine"으로 시작하는 파트 존재
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS → **Step 5:** 커밋

### Task 5: 고가 철로·승강장·하천

**Files:** Create `tools/osm/rail_water.py`, `tests/py/test_osm_rail_water.py`

**Interfaces:**
- Produces: `DECK_Y = 18` (상판 윗면)
- Produces: `rail_parts(ways) -> list[PartSpec]` — railway=rail 전부 상판(폭 = 선로당 6스터드, 겹치는 선로는 하나로 합치지 않고 각자) + 교각(40스터드 간격, 상판 아래) + 레일 2줄. bridge 여부와 상관없이 1구역 안 철로는 모두 고가로
- Produces: `platform_parts(ways) -> list[PartSpec]` — railway=platform 윤곽을 높이 DECK_Y+2로, 지붕(4스터드 위, 기둥 16스터드 간격)
- Produces: `water_luau(ways) -> str` — waterway 선분마다 `workspace.Terrain:FillBlock(CFrame, Vector3(len, 10, 폭), Enum.Material.Water)` (폭 = width 태그 m×1.6, 없으면 stream 12m, river 120m), 아래에 Sand 바닥, 옆 둑 Grass. 선분 끝에 FillCylinder로 이음. 10줄마다 `task.wait()`
- Produces: `water_cuts(ways) -> list[(x0,z0,x1,z1,width)]` — 바닥 파트에서 비울 구간 (Task 6)

- [ ] **Step 1: 실패하는 테스트**
  - 데이터 전체 `rail_parts` → 이름 "Deck" 파트 ≥ 10개, 모든 Deck 윗면 = 18
  - `water_luau` 결과에 `Enum.Material.Water` 포함, "task.wait()" 포함, 양근천(width 40) 선분의 폭 64 포함
  - `platform_parts` → 승강장 8개(OSM platform 8개) 모두 윗면 20
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS → **Step 5:** 커밋

### Task 6: 1구역 조립 + 게임 태그 + 구역 이동

**Files:** Create `tools/osm/zone1.py`, `tests/py/test_osm_zone1.py`; Modify `tools/genmap.py`, `tools/map_check.py`; Delete use of `tools/town1.py` (파일은 삭제)

**Interfaces:**
- Consumes: Task 1~5 전부, genmap의 `part()/deco()/sensor()/sign()/folder()/surface_text()`
- Produces: `build_zone1(helpers) -> dict(parts, zone_area=(center, size), floor_holes, spots, boss, rain, spawn=(x,z,yaw), boards, gate2=(x,z,yaw), food=list[(x,z)])`
- 배치 규칙: 바닥 = bbox 전체 연한 잔디 파트(하천 구간은 비움 — 바닥을 하천 기준 여러 조각으로), 스폰 = 정류장 A, 우유 비 = 역 앞 광장(로터리와 역 건물 사이), 보스 = "양평시장공영주차장" 중심, 농구·철봉·침대 = "양일중고등학교" 부지 안 빈 곳(없으면 가장 큰 green), 순위판 2개 = 정류장 A 옆, 출처 안내판 = 정류장 A 옆, 2구역 문 = bbox 서쪽 가장자리와 만나는 가장 넓은 도로
- genmap: 1구역 = zone1 결과, 2·3·4구역 중심 x를 1구역 서쪽 가장자리 바깥으로 이동(겹치지 않게, 상대 배치·연결 경사로 유지)

- [ ] **Step 1: 실패하는 테스트**
  - `food_not_in_buildings`: 60개 음식 좌표 전부 어떤 건물 윤곽 안에도 없음
  - `zone_areas_disjoint`: genmap 결과의 ZoneArea 4개 XZ 사각형이 서로 겹치지 않음
  - `part_budget`: 1구역 폴더 아래 파트 수 ≤ 8000
  - 스폰에서 역 건물 중심까지 거리 ≤ 250 스터드, 스폰 yaw가 역 방향(±20°)
  - map_check: 구역별 태그 개수 통과 (1구역 FoodSpawn 60, BossSpawn 1~3구역, StarPoint 19, GlobalBoard·WeeklyBoard 각 1, ZoneGate 2·3·4)
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** `python3 -m pytest tests/py -q` PASS, `python3 tools/genmap.py && python3 tools/map_check.py` → "map ok", `rojo build map.project.json -o map/BaseMap.rbxm` 성공, `luau tests/run.luau` 57 passed
- [ ] **Step 5:** `tools/preview.py`로 위에서 본 그림 + 정류장 A 눈높이 그림 생성해 확인 → 커밋·push

### Task 7: 스튜디오 기본 적용 (MCP)

**Files:** Create `tools/studio/clear_terrain.luau`, `tools/studio/terrain_water.luau`(Task 5 생성물 저장), `tools/studio/lighting.luau`

- [ ] **Step 1 (서준이):** GitHub Desktop Pull → 스튜디오에서 기존 BaseMap 삭제(또는 Claude가 MCP로 삭제) → 새 `map/BaseMap.rbxm` 끌어다 놓기
- [ ] **Step 2:** MCP `execute_luau`로 `clear_terrain.luau`(`workspace.Terrain:Clear()`) 실행
- [ ] **Step 3:** `terrain_water.luau`를 300줄씩 나눠 실행 (각 덩어리 끝 `task.wait()`)
- [ ] **Step 4:** `lighting.luau` 실행 (앞서 넣은 대기·블룸·색보정 값 그대로 저장한 것)
- [ ] **Step 5:** `screen_capture` 3장 — 정류장 A 눈높이(역 방향), 위에서 본 전체, 양근천 다리. 하천이 바닥 파트와 겹치지 않는지, 역이 보이는지 확인 → 문제 있으면 Task 5/6로 돌아가 수정
- [ ] **Step 6:** 커밋

### Task 8: 랜드마크 상세 (MCP)

**Files:** Create `tools/studio/landmarks/station.luau`, `bus_stop_a.luau`, `roundabout.luau`, `ostar_tower.luau`, `market.luau`

각 파일은 `workspace.BaseMap.Landmarks.<이름>` 폴더를 지우고 다시 만드는 멱등 스크립트. OSM 윤곽 위치에 맞춤.
- **station:** 역 윤곽 위 고가 역사(유리 정면, "양평역 / Yangpyeong" 간판, 경의중앙선 청록 띠), 로터리 쪽 출입구 계단·엘리베이터 탑, 승강장 연결
- **bus_stop_a:** 지붕, 뒷유리, 의자, 노선 안내판("양평역" 정류장명), 버스 정보 표시기, 인도 경계석
- **roundabout:** 가운데 화단·조형, 횡단보도, 정지선
- **ostar_tower:** 38층 몸체에 층 띠·세로 줄, 옥상 구조물, 단지명 간판
- **market:** OSM 시장길·장터길을 따라 골목 지붕(아치)·노점 줄·입구 간판 "양평물맑은시장", 시장 쉼터 건물 간판

- [ ] **Step 1~5 (랜드마크마다 반복):** 스크립트 작성 → MCP 실행 → `screen_capture`로 정류장 A 시점과 근접 시점 확인 → 고칠 점 반영해 재실행 → 저장소에 커밋
- [ ] **Step 6:** 서준이 사진을 받으면 station·bus_stop_a 외관을 사진에 맞춰 수정 (사진 전엔 이 단계 보류, 계획 완료 조건 아님)

### Task 9: 게임 동작 확인 + 마무리

**Files:** Modify `docs/PLAYTEST.md`, `README.md`

- [ ] **Step 1:** MCP `start_stop_play`로 플레이 → `get_console_output`에 빨간 오류 없음, 스폰이 정류장 A
- [ ] **Step 2:** MCP 플레이 중 `execute_luau`(Server)로 테스트 키 1,000 추가 → 2구역 문 열림 확인, 음식 하나 먹이기(캐릭터를 음식 위치로 이동) → 키 증가 확인
- [ ] **Step 3:** 정지 → `save_place` (서준이 확인 후)
- [ ] **Step 4:** PLAYTEST 3번 항목을 새 맵 기준으로, README에 OSM 출처와 `tools/osm` 재생성 방법 추가
- [ ] **Step 5:** `python3 -m pytest tests/py -q`, `luau tests/run.luau`, `/home/claude/check.sh` 통과 → 커밋·push
