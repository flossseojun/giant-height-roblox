import json, math, os, subprocess, sys
import pytest
from osm.project import load, classify
from osm.zone1 import DATA, point_in_poly, centroid

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")


@pytest.fixture(scope="module")
def model():
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "genmap.py")], check=True, capture_output=True)
    return json.load(open(os.path.join(ROOT, "map", "BaseMap.model.json"), encoding="utf-8"))


def walk(n, fn):
    fn(n)
    for c in n.get("children", []):
        walk(c, fn)


def tagged(model, tag):
    out = []
    walk(model, lambda n: out.append(n) if tag in n.get("properties", {}).get("Tags", []) else None)
    return out


def pos(n):
    return n["properties"]["CFrame"]["CFrame"]["position"]


def test_food_not_in_buildings(model):
    d = load(DATA)
    blds = [w.pts for w in d.ways if classify(w) in ("building", "station")]
    foods = [n for n in tagged(model, "FoodSpawn") if n.get("attributes", {}).get("Zone") == 1]
    assert len(foods) == 60
    for f in foods:
        x, _, z = pos(f)
        assert not any(point_in_poly(x, z, b) for b in blds), (x, z)


def test_zone_areas_disjoint(model):
    rects = []
    for n in tagged(model, "ZoneArea"):
        x, _, z = pos(n)
        sx, _, sz = n["properties"]["Size"]
        rects.append((x - sx / 2, x + sx / 2, z - sz / 2, z + sz / 2))
    assert len(rects) == 4
    for i in range(4):
        for j in range(i + 1, 4):
            a, b = rects[i], rects[j]
            overlap = min(a[1], b[1]) - max(a[0], b[0]) > 0.01 and min(a[3], b[3]) - max(a[2], b[2]) > 0.01
            assert not overlap, (i, j, a, b)


def test_part_budget(model):
    z1 = next(c for c in model["children"] if c["name"] == "1_양평읍")
    n = [0]
    walk(z1, lambda x: n.__setitem__(0, n[0] + 1) if x.get("className") in ("Part", "WedgePart") else None)
    assert n[0] <= 13000, n[0]  # 건물 스타일 디테일로 8000→13000 (Ruling)


def test_spawn_faces_station(model):
    lob = next(c for c in model["children"] if c["name"] == "Lobby")
    sp = next(c for c in lob["children"] if c["name"] == "SpawnLocation")
    x, _, z = pos(sp)
    rot = sp["properties"]["CFrame"]["CFrame"]["orientation"]
    look = (-rot[0][2], -rot[2][2])  # 로컬 −Z의 월드 방향 (x, z)
    d = load(DATA)
    st = next(w for w in d.ways if classify(w) == "station")
    cx, cz = centroid(st.pts)
    assert math.hypot(cx - x, cz - z) <= 250
    ang = math.degrees(math.atan2(cz - z, cx - x) - math.atan2(look[1], look[0]))
    ang = (ang + 180) % 360 - 180
    assert abs(ang) <= 20, ang


def test_map_check_passes(model):
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "map_check.py")], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout


def test_monster_spawns(model):
    d = load(DATA)
    blds = [w.pts for w in d.ways if classify(w) in ("building", "station")]
    sp = tagged(model, "MonsterSpawn")
    z1 = [n for n in sp if n["attributes"]["Zone"] == 1]
    kinds = [n["attributes"]["Species"] for n in z1]
    assert kinds.count("pigeon") >= 4 and kinds.count("duck") >= 3, kinds
    for n in z1:
        x, _, z = pos(n)
        assert not any(point_in_poly(x, z, b) for b in blds), (x, z)
    want = {2: {"carp", "heron"}, 3: {"boar", "crow"}, 4: {"star"}}
    for zone, species in want.items():
        got = [n["attributes"]["Species"] for n in sp if n["attributes"]["Zone"] == zone]
        assert len(got) >= 2 and set(got) == species, (zone, got)
    for n in sp:
        assert 8 <= n["attributes"]["Radius"] <= 30
