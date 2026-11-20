"""1구역 조립: OSM 건물·도로·철로 + 바닥(하천 구간 비움) + 게임 시설 배치."""
import math
import os

from osm.project import load, classify, to_studs, SCALE
from osm.buildings import building_parts, floors
from osm.roads import road_parts, road_segments
from osm.rail_water import rail_parts, platform_parts, water_cuts, water_luau
from osm import landmarks as LM

DATA = os.path.join(os.path.dirname(__file__), "..", "..", "data", "yangpyeong_station.osm")
BBOX = (37.4880, 127.4855, 37.4975, 127.4985)  # 남, 서, 북, 동
GRASS = [128 / 255, 168 / 255, 108 / 255]
CELL = 32  # 바닥 칸 크기(스터드)
# 정류장 A: 역전길 북쪽, 오스타 코아루 맞은편 (역 기준 동 −116.9m, 북 −49.0m)
STOP_A_M = (-116.9, -49.0)


def bounds():
    x0, z0 = to_studs(BBOX[2], BBOX[1])  # 북서
    x1, z1 = to_studs(BBOX[0], BBOX[3])  # 남동
    return x0, x1, z0, z1


def point_in_poly(x, z, pts):
    inside = False
    n = len(pts)
    for i in range(n):
        x1, z1 = pts[i]
        x2, z2 = pts[(i + 1) % n]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1 + 1e-12) + x1:
            inside = not inside
    return inside


def seg_dist(px, pz, x0, z0, x1, z1):
    dx, dz = x1 - x0, z1 - z0
    L2 = dx * dx + dz * dz
    t = 0 if L2 == 0 else max(0, min(1, ((px - x0) * dx + (pz - z0) * dz) / L2))
    return math.hypot(px - (x0 + t * dx), pz - (z0 + t * dz))


def centroid(pts):
    return sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)


class Obstacles:
    def __init__(self, polys):
        self.polys = [(p, min(q[0] for q in p), max(q[0] for q in p), min(q[1] for q in p), max(q[1] for q in p))
                      for p in polys]

    def hit(self, x, z, margin=0.0):
        for p, a, b, c, d in self.polys:
            if a - margin <= x <= b + margin and c - margin <= z <= d + margin:
                if point_in_poly(x, z, p):
                    return True
                if margin and any(seg_dist(x, z, *p[i], *p[(i + 1) % len(p)]) < margin for i in range(len(p))):
                    return True
        return False


def _nearest_on_seg(px, pz, x0, z0, x1, z1):
    dx, dz = x1 - x0, z1 - z0
    L2 = dx * dx + dz * dz or 1.0
    t = max(0.0, min(1.0, ((px - x0) * dx + (pz - z0) * dz) / L2))
    return x0 + dx * t, z0 + dz * t


def street_ctx(way, segs, main_w=10.0):
    """건물 → {"street": 가장 가까운 도로 위 점, "downtown": 폭 main_w 이상 큰길가(가장자리 12스터드 이내)}"""
    cx, cz = centroid(way.pts)
    xs = [p[0] for p in way.pts]
    zs = [p[1] for p in way.pts]
    rad = max(max(xs) - min(xs), max(zs) - min(zs)) / 2
    best, best_d, down = None, 1e18, False
    for x0, z0, x1, z1, wd in segs:
        nx, nz = _nearest_on_seg(cx, cz, x0, z0, x1, z1)
        dd = math.hypot(nx - cx, nz - cz)
        if dd < best_d:
            best, best_d = (nx, nz), dd
        if wd >= main_w and dd - rad - wd / 2 < 12:
            down = True
    return {"street": best if best_d < rad + 40 else None, "downtown": down}


def spec_to_node(spec, h, prefix=""):
    """PartSpec → genmap part() 노드 (표지판 글씨·투명도·충돌 포함)"""
    children = None
    if spec.get("label"):
        text, face, fg, ppu = spec["label"]
        children = [h["surface_text"](text, face, list(fg), ppu=ppu)]
    return h["part"](prefix + spec["name"], spec["pos"], spec["size"], list(spec.get("color", (0.7, 0.7, 0.7))),
                     spec.get("material", "SmoothPlastic"), transparent=spec.get("transparency", 0),
                     collide=spec.get("collide", True), cls=spec.get("cls", "Part"), orient=spec["rot"],
                     shape=spec.get("shape"), extra={"CanQuery": spec.get("collide", True)}, children=children)


def build_zone1(h):
    data = load(DATA)
    x0, x1, z0, z1 = bounds()
    inb = lambda x, z, m=0: x0 - m <= x <= x1 + m and z0 - m <= z <= z1 + m
    ways = data.ways
    kind = {w.id: classify(w) for w in ways}
    blds = [w for w in ways if kind[w.id] in ("building", "station") and inb(*centroid(w.pts))]
    roads = [w for w in ways if kind[w.id] == "road" and any(inb(x, z) for x, z in w.pts)]
    rails = [w for w in ways if kind[w.id] == "rail"]
    plats = [w for w in ways if kind[w.id] == "platform"]
    waters = [w for w in ways if kind[w.id] == "water"]
    obstacles = Obstacles([w.pts for w in blds])

    def named(name):
        return next((w for w in ways if w.tags.get("name") == name), None)
    station = next(w for w in ways if kind[w.id] == "station")
    st_c = centroid(station.pts)

    groups = {"Buildings": [], "Roads": [], "Railway": [], "Platforms": []}
    bmodels = {}  # 건물마다 하나의 Model (부술 때 한 번에 숨기기)
    segs = road_segments(roads)
    for w in blds:
        if kind[w.id] == "station":
            continue  # 역 건물은 랜드마크 작업에서 상세 제작 (자리 표시용 기단만)
        ctx = street_ctx(w, segs)
        n_fl = floors(w.tags, w.id, ctx["downtown"])
        bmodel = {"name": f"Building_{w.id}", "className": "Model",
                  "properties": {"Tags": ["Breakable"]},
                  "attributes": {"Floors": n_fl, "HeightCm": n_fl * 300, "Zone": 1},
                  "children": [spec_to_node(s, h, f"B{w.id}_") for s in building_parts(w, ctx)]}
        bmodels[w.id] = bmodel
        groups["Buildings"].append(bmodel)
    for w in roads:
        for s in road_parts(w):
            if inb(s["pos"][0], s["pos"][2], 10):
                groups["Roads"].append(spec_to_node(s, h, f"R{w.id}_"))
    for s in rail_parts(rails):
        if inb(s["pos"][0], s["pos"][2]):
            groups["Railway"].append(spec_to_node(s, h))
    groups["Platforms"] = [spec_to_node(s, h) for s in platform_parts(plats)]
    # 바닥: 하천과 겹치는 칸은 비우고, 줄마다 이어진 칸을 하나로 합침
    cuts = [c_ for c_ in water_cuts(waters)]
    holes = []
    floor = []
    nz = int(math.ceil((z1 - z0) / CELL))
    nx = int(math.ceil((x1 - x0) / CELL))
    for j in range(nz):
        zc = z0 + (j + 0.5) * CELL
        run = None
        for i in range(nx + 1):
            xc = x0 + (i + 0.5) * CELL
            wet = i < nx and any(seg_dist(xc, zc, a, b, c_, d) < wd / 2 + CELL * 0.75 for a, b, c_, d, wd in cuts)
            if i < nx and not wet:
                run = i if run is None else run
                continue
            if i < nx:
                holes.append((xc, zc))
            if run is not None:
                xa, xb = x0 + run * CELL, min(x1, x0 + i * CELL)
                floor.append(h["part"](f"Floor{j}_{run}", ((xa + xb) / 2, -2, zc), (xb - xa, 4, CELL), GRASS, "Grass"))
                run = None
    groups["Floor"] = floor

    # 음식 60개: 도로 위, 건물·하천 밖, 서로 30스터드 이상
    cands = []
    for a, b, c_, d, wd in road_segments(roads):
        L = math.hypot(c_ - a, d - b)
        for k in range(int(L // 24) + 1):
            t = (k + 0.5) / (int(L // 24) + 1)
            x, z = a + (c_ - a) * t, b + (d - b) * t
            if inb(x, z, -20) and not obstacles.hit(x, z, 3) and \
                    all(seg_dist(x, z, *cc[:4]) > cc[4] / 2 + 6 for cc in cuts):
                cands.append((x, z))
    food = []
    if cands:
        food.append(min(cands, key=lambda p: math.hypot(p[0] - st_c[0], p[1] - st_c[1])))
        while len(food) < 60:
            best = max(cands, key=lambda p: min(math.hypot(p[0] - f[0], p[1] - f[1]) for f in food))
            if min(math.hypot(best[0] - f[0], best[1] - f[1]) for f in food) < 30:
                break
            food.append(best)

    # 스폰 = 정류장 A, 역을 바라봄
    sx, sz = STOP_A_M[0] * SCALE, -STOP_A_M[1] * SCALE
    spawn_yaw = math.atan2(st_c[1] - sz, st_c[0] - sx)
    # 랜드마크
    m2s = lambda e, n: (e * SCALE, -n * SCALE)  # 역 기준 동·북 미터 → 스터드
    rb = next(w for w in ways if w.id == 587644188)
    rbc = centroid(rb.pts)
    def unit_dir(a, b):
        (ax, az), (bx, bz) = m2s(*a), m2s(*b)
        L = math.hypot(bx - ax, bz - az)
        return ((bx - ax) / L, (bz - az) / L)
    approaches = [(unit_dir((-78.4, -38.5), (-151.2, -82.7)), 14 * SCALE),
                  (unit_dir((-71.9, -25.6), (-79.2, -13.9)), 7 * SCALE),
                  (unit_dir((-78.4, -38.5), (-53.6, -77.2)), 6 * SCALE)]
    road_dir = approaches[0][0]
    side = (-road_dir[1], road_dir[0])
    road_pt = m2s(-111.2, -58.4)
    if (road_pt[0] - sx) * side[0] + (road_pt[1] - sz) * side[1] < 0:
        side = (-side[0], -side[1])
    ostar_w = named("현대성우오스타코아루아파트")
    lm = []
    lm += [dict(s_, name="Station_" + s_["name"]) for s_ in LM.station(station.pts, rbc)]
    lm += [dict(s_, name="BusStopA_" + s_["name"]) for s_ in LM.bus_stop(sx, sz, road_dir, side)]
    lm += [dict(s_, name="Roundabout_" + s_["name"]) for s_ in LM.roundabout(rbc[0], rbc[1], approaches)]
    lm += [dict(s_, name="Ostar_" + s_["name"]) for s_ in LM.ostar(ostar_w.pts, (sx, sz))]
    lm += [dict(s_, name="Market_" + s_["name"]) for s_ in LM.market([(-74, 518), (-60, 526), (37, 591), (102, 636)])]
    # 오스타 이름판은 오스타 건물 모델 안에 (건물이 부서지면 같이 사라짐)
    groups["Landmarks"] = [spec_to_node(s_, h) for s_ in lm if not s_["name"].startswith("Ostar_")]
    bmodels[ostar_w.id]["children"] += [spec_to_node(s_, h) for s_ in lm if s_["name"].startswith("Ostar_")]

    # 스폰은 정류장의 역 쪽 끝 바로 앞, 역을 바라봄. 순위판은 정류장 뒤편에서 도로 쪽을 봄
    to_st = (-road_dir[0], -road_dir[1]) if (st_c[0] - sx) * -road_dir[0] + (st_c[1] - sz) * -road_dir[1] > 0 \
        else road_dir
    stop_x, stop_z = sx, sz
    sx, sz = stop_x + to_st[0] * 13 + side[0] * 1, stop_z + to_st[1] * 13 + side[1] * 1
    spawn_yaw = math.atan2(st_c[1] - sz, st_c[0] - sx)
    boards_override = [(stop_x - side[0] * 12 - to_st[0] * k, 9, stop_z - side[1] * 12 - to_st[1] * k) for k in (8, 38)]
    board_yaw_override = math.atan2(side[1], side[0])

    # 우유 비 = 로터리와 역 건물 사이
    rain = ((-60 * SCALE), (15 * SCALE))

    def free_point_in(poly, clearance):
        xs, zs = [p[0] for p in poly], [p[1] for p in poly]
        cx_, cz_ = centroid(poly)
        best = None
        for gi in range(15):
            for gj in range(15):
                x = min(xs) + (max(xs) - min(xs)) * (gi + 0.5) / 15
                z = min(zs) + (max(zs) - min(zs)) * (gj + 0.5) / 15
                if point_in_poly(x, z, poly) and not obstacles.hit(x, z, clearance):
                    dd = math.hypot(x - cx_, z - cz_)
                    if best is None or dd < best[0]:
                        best = (dd, x, z)
        return (best[1], best[2]) if best else (cx_, cz_)

    pitch = max((w for w in ways if w.tags.get("leisure") == "pitch" and inb(*centroid(w.pts))
                 and point_in_poly(*centroid(w.pts), named("양일중고등학교").pts)), key=lambda w: len(w.pts),
                default=None)
    px, pz = centroid(pitch.pts) if pitch else free_point_in(named("양일중고등학교").pts, 20)
    spots = {"hoop": (px - 35, pz - 25), "bar": (px + 35, pz - 25), "beds": (px, pz + 35)}
    lot = next(w for w in ways if w.id == 1185455848)  # 시장 옆 노상 주차장
    boss = free_point_in(lot.pts, 10)
    # 순위판·출처 안내판: 정류장 앞(역 방향) 30스터드, 좌우로
    fx, fz = math.cos(spawn_yaw), math.sin(spawn_yaw)
    rx, rz = -fz, fx
    boards = boards_override

    # 2구역 문: 서쪽 가장자리와 만나는 가장 넓은 도로
    gate = None
    for a, b, c_, d, wd in road_segments(roads):
        if (a - x0) * (c_ - x0) <= 0 and a != c_:
            t = (x0 - a) / (c_ - a)
            z = b + (d - b) * t
            if z0 + 200 < z < z1 - 200 and (gate is None or wd > gate[2]):
                gate = (x0, z, wd, math.atan2(d - b, c_ - a))

    # 몬스터 출현 지점: 비둘기 = 시장 골목·역 광장, 오리 = 양근천 물가(물 가장자리 밖 땅)
    monster_spawns = []
    for x, z in [(-67, 522), (-30, 546), (10, 572), (70, 613), (rain[0], rain[1]), (rain[0] - 30, rain[1] + 25)]:
        if inb(x, z) and not obstacles.hit(x, z, 3):
            monster_spawns.append((x, z, "pigeon", 12))
    streams = [w for w in waters if w.tags.get("waterway") == "stream" and w.tags.get("name") == "양근천"]

    def near_water(x, z, d):
        return any(seg_dist(x, z, a[0], a[1], b[0], b[1]) < d for w in waters for a, b in zip(w.pts, w.pts[1:]))
    ducks = []
    for w in streams:
        for a, b in zip(w.pts, w.pts[1:]):
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            if L < 1:
                continue
            mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            nx, nz = -(b[1] - a[1]) / L, (b[0] - a[0]) / L
            for sgn in (1, -1):
                x, z = mx + nx * 42 * sgn, mz + nz * 42 * sgn
                if (inb(x, z, -40) and not obstacles.hit(x, z, 4) and not near_water(x, z, 38)
                        and all(math.hypot(x - dx, z - dz) > 120 for dx, dz, _, _ in ducks)):
                    ducks.append((x, z, "duck", 14))
                    break
    monster_spawns += ducks[:5]

    return {
        "monster_spawns": monster_spawns,
        "groups": groups,
        "zone_area": (((x0 + x1) / 2, 500, (z0 + z1) / 2), (x1 - x0, 1100, z1 - z0)),
        "bounds": (x0, x1, z0, z1),
        "holes": holes,
        "spots": spots,
        "boss": boss,
        "rain": rain,
        "spawn": (sx, sz, spawn_yaw),
        "boards": boards,
        "board_yaw": board_yaw_override,
        "gate2": gate,
        "food": food,
        "water_luau": water_luau(waters),
        "station_center": st_c,
    }
