#!/usr/bin/env python3
"""양평 테마 기본 맵(map/BaseMap.model.json) 생성기.

실행: python3 tools/genmap.py && rojo build map.project.json -o map/BaseMap.rbxm
검사: python3 tools/map_check.py
좌표 단위는 스터드. 바닥 윗면 y=0(1·2구역), y=300(3구역 용문산).
코드가 찾는 태그(FoodSpawn, ZoneArea, ZoneGate, Hoop, BallRack, Bar, Bed, MilkRainSpot, GlobalBoard, BossSpawn)는
장식을 바꿔도 반드시 유지할 것.
"""
import json
import math
import os
import random

random.seed(7)
ID = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
CYL_UP = [[0, -1, 0], [1, 0, 0], [0, 0, 1]]  # 원기둥(X축)을 세로로


def rgb(r, g, b):
    return [r / 255, g / 255, b / 255]


def part(name, pos, size, color=None, material="SmoothPlastic", transparent=0, collide=True,
         tags=None, attrs=None, cls="Part", orient=None, shape=None, extra=None, children=None):
    props = {
        "Anchored": True,
        "Size": list(size),
        "CFrame": {"CFrame": {"position": list(pos), "orientation": orient or ID}},
        "Material": material,
        "Transparency": transparent,
        "CanCollide": collide,
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
    }
    if color:
        props["Color"] = color
    if tags:
        props["Tags"] = tags
    if shape:
        props["Shape"] = shape
    if extra:
        props.update(extra)
    node = {"name": name, "className": cls, "properties": props}
    if attrs:
        node["attributes"] = attrs
    if children:
        node["children"] = children
    return node


def deco(name, pos, size, color, material="SmoothPlastic", **kw):
    """장식: 카메라·클릭 방해 안 하게 CanQuery 끔"""
    extra = kw.pop("extra", None) or {}
    extra.setdefault("CanQuery", False)
    return part(name, pos, size, color, material, extra=extra, **kw)


def sensor(name, pos, size, tag, zone):
    return part(name, pos, size, transparent=1, collide=False, tags=[tag], attrs={"Zone": zone},
                extra={"CanTouch": True, "CanQuery": False})


def folder(name, children):
    return {"name": name, "className": "Folder", "children": children}


def surface_text(text, face="Front", color=rgb(255, 255, 255), ppu=12):
    label = {"name": "Text", "className": "TextLabel", "properties": {
        "Text": text, "TextScaled": True, "Font": "FredokaOne",
        "TextColor3": color, "TextStrokeTransparency": 0.4,
        "BackgroundTransparency": 1,
        "Size": {"UDim2": [[1, 0], [1, 0]]},
    }}
    return {"name": "Sign" + face, "className": "SurfaceGui", "properties": {
        "Face": face, "SizingMode": "PixelsPerStud", "PixelsPerStud": ppu,
    }, "children": [label]}


def sign(name, pos, size, text, color, text_color=rgb(255, 255, 255), faces=("Front",)):
    return deco(name, pos, size, color, children=[surface_text(text, f, text_color) for f in faces])


def tree(name, base, trunk_h, trunk_d, crown_d, crown_color, trunk_color=rgb(110, 75, 45)):
    x, y, z = base
    return folder(name, [
        deco("Trunk", (x, y + trunk_h / 2, z), (trunk_h, trunk_d, trunk_d), trunk_color, "Wood",
             shape="Cylinder", orient=CYL_UP),
        deco("Crown", (x, y + trunk_h + crown_d * 0.3, z), (crown_d, crown_d * 0.8, crown_d), crown_color,
             "Grass", shape="Ball", collide=False),
    ])


ZONES = [
    dict(id=1, name="1_양평읍", center=(0, 0, 0), size=(240, 240), color=rgb(185, 185, 180), material="Concrete", k=1),
    dict(id=2, name="2_두물머리", center=(260, 0, 0), size=(280, 280), color=rgb(110, 185, 90), material="Grass", k=3),
    dict(id=3, name="3_용문산", center=(260, 300, 800), size=(400, 400), color=rgb(70, 140, 70), material="Grass", k=6),
]
AREAS = {
    1: ((0, 500, 0), (240, 1100, 240)),
    2: ((260, 500, 0), (280, 1100, 280)),
    3: ((260, 500, 570), (400, 1100, 860)),
}
# 보스 자리 (구역 안쪽 빈 곳)
BOSS = {1: (40, -40), 2: (200, 40), 3: (340, 820)}
WATER = rgb(90, 160, 220)


def facility_spots(z):
    cx, top, cz = z["center"]
    sx, sz = z["size"]
    return dict(hoop=(cx - 0.3 * sx, cz + 0.3 * sz), bar=(cx + 0.3 * sx, cz + 0.3 * sz),
                beds=(cx + 0.3 * sx, cz - 0.3 * sz))


def decorations(z):
    """구역별 양평 장식과, 음식이 피해야 할 사각형 목록 (x0, x1, z0, z1)"""
    zid = z["id"]
    top = z["center"][1]
    out, avoid = [], []
    if zid == 1:
        out.append(deco("NamhanRiver", (0, top + 0.1, -110), (240, 0.4, 20), WATER, "Glass", transparent=0.3,
                        collide=False))
        out.append(sign("RiverSign", (60, top + 4, -98), (16, 4, 0.5), "남한강", rgb(40, 90, 150)))
        out.append(deco("YangpyeongStation", (0, top + 10, 98), (60, 20, 16), rgb(235, 235, 240), "Concrete"))
        out.append(deco("StationRoof", (0, top + 21, 98), (66, 2, 20), rgb(60, 90, 150), "Metal"))
        out.append(sign("StationSign", (0, top + 16, 89.7), (30, 5, 0.5), "양평역", rgb(30, 60, 140)))
        avoid.append((-35, 35, 85, 112))
        stalls = []
        roofs = [rgb(230, 80, 70), rgb(70, 140, 230), rgb(250, 200, 60), rgb(90, 190, 110)]
        for i, sz_ in enumerate(range(-40, 40, 16)):
            for j, sx_ in enumerate((-100, -60)):
                stalls.append(deco(f"Stall{i}{j}", (sx_, top + 2, sz_), (10, 4, 10), rgb(170, 120, 70), "Wood"))
                stalls.append(deco(f"Awning{i}{j}", (sx_, top + 7, sz_), (12, 1, 12), roofs[(i + j) % 4], "Fabric"))
        out.append(folder("MulmalgeunMarket", stalls))
        out.append(sign("MarketSign", (-80, top + 14, 46), (40, 6, 1), "물맑은시장", rgb(200, 60, 50),
                        faces=("Front", "Back")))
        avoid += [(-110, -50, -50, 50), (-20, 20, -75, -65), (-10, 10, 30, 50)]
    elif zid == 2:
        out.append(deco("NamhanRiver", (260, top + 0.1, -126), (280, 0.4, 28), WATER, "Glass", transparent=0.3,
                        collide=False))
        out.append(deco("BukhanRiver", (386, top + 0.12, 0), (28, 0.4, 280), WATER, "Glass", transparent=0.3,
                        collide=False))
        out.append(sign("DumulmeoriSign", (300, top + 10, -100), (50, 8, 1), "두물머리", rgb(60, 110, 60),
                        faces=("Front", "Back")))
        out.append(tree("ZelkovaTree", (300, top, -40), 30, 7, 46, rgb(70, 140, 60)))
        avoid.append((275, 325, -65, -15))
        lotus = []
        for i in range(14):
            x, zz = 200 + random.uniform(-40, 40), -100 + random.uniform(-6, 6)
            lotus.append(deco(f"Pad{i}", (x, top + 0.3, zz), (0.4, 5, 5), rgb(60, 150, 70), "Grass",
                              shape="Cylinder", orient=CYL_UP, collide=False))
            lotus.append(deco(f"Flower{i}", (x, top + 1.2, zz), (2, 2, 2), rgb(255, 150, 190), "Neon",
                              shape="Ball", collide=False))
        out.append(folder("LotusField", lotus))
        avoid.append((155, 245, -112, -88))
        out.append(folder("SailBoat", [
            deco("Hull", (150, top + 1.5, -126), (24, 3, 8), rgb(130, 85, 50), "Wood"),
            deco("Mast", (150, top + 11, -126), (1, 18, 1), rgb(100, 70, 40), "Wood"),
            deco("Sail", (151, top + 12, -126), (0.4, 12, 7), rgb(230, 190, 110), "Fabric"),
        ]))
    else:
        out.append(sign("SummitSign", (260, top + 14, 640), (50, 10, 1), "용문산 정상 1,157m", rgb(90, 70, 50),
                        faces=("Front", "Back")))
        out.append(folder("Yongmunsa", [
            deco("Base", (240, top + 6, 950), (40, 12, 28), rgb(160, 60, 45), "Wood"),
            deco("Roof", (240, top + 14, 950), (50, 4, 36), rgb(60, 60, 70), "Slate"),
            sign("TempleSign", (240, top + 9, 935.7), (16, 4, 0.5), "용문사", rgb(40, 30, 30),
                 text_color=rgb(255, 220, 120)),
        ]))
        avoid.append((215, 265, 930, 970))
        out.append(tree("GiantGinkgo", (150, top, 700), 70, 12, 90, rgb(250, 205, 50)))
        avoid.append((105, 195, 655, 745))
        rocks = []
        for i in range(10):
            x, zz = 260 + random.uniform(-180, 180), 800 + random.uniform(-180, 180)
            bx, bz = BOSS[3]
            if (x - bx) ** 2 + (zz - bz) ** 2 < 60 ** 2:
                continue
            s = random.uniform(8, 20)
            rocks.append(deco(f"Rock{i}", (x, top + s * 0.3, zz), (s, s * 0.7, s * 1.2), rgb(120, 120, 115), "Rock"))
            avoid.append((x - s, x + s, zz - s, zz + s))
        out.append(folder("Rocks", rocks))
        clouds = []
        for i in range(16):
            a = i / 16 * math.tau
            clouds.append(deco(f"Cloud{i}", (260 + math.cos(a) * 230, top - 20 + random.uniform(-15, 5),
                                             800 + math.sin(a) * 230),
                               (70, 30, 50), rgb(255, 255, 255), shape="Ball", transparent=0.25, collide=False))
        out.append(folder("Clouds", clouds))
    return out, avoid


def zone_folder(z):
    cx, top, cz = z["center"]
    sx, sz = z["size"]
    k, zid = z["k"], z["id"]
    kids = [part("Floor", (cx, top - 2, cz), (sx, 4, sz), z["color"], z["material"])]
    a_pos, a_size = AREAS[zid]
    kids.append(sensor("ZoneArea", a_pos, a_size, "ZoneArea", zid))

    deco_parts, avoid = decorations(z)
    kids.append(folder("Decor", deco_parts))

    spots = facility_spots(z)
    hx, hz = spots["hoop"]
    bx, bz = spots["bar"]
    ex, ez = spots["beds"]
    pad = 14 * k
    bsx, bsz = BOSS[zid]
    avoid += [(hx - pad, hx + pad + 10 * k, hz - pad, hz + pad + 10 * k), (bx - pad, bx + pad, bz - pad, bz + pad),
              (ex - pad, ex + pad, ez - pad, ez + pad), (cx - 8, cx + 8, cz - 8, cz + 8),
              (bsx - 12 * k, bsx + 12 * k, bsz - 12 * k, bsz + 12 * k)]

    foods, tries = [], 0
    while len(foods) < 20 and tries < 5000:
        tries += 1
        x = cx + random.uniform(-0.42, 0.42) * sx
        zz = cz + random.uniform(-0.42, 0.42) * sz
        if any(x0 <= x <= x1 and z0 <= zz <= z1 for x0, x1, z0, z1 in avoid):
            continue
        if any((x - fx) ** 2 + (zz - fz) ** 2 < (0.07 * sx) ** 2 for fx, fz in foods):
            continue
        foods.append((x, zz))
    assert len(foods) == 20, f"zone {zid}: only {len(foods)} food spots"
    kids.append(folder("FoodSpawns", [
        sensor(f"FoodSpawn{i + 1}", (x, top + 2 * k, zz), (2 * k, 2 * k, 2 * k), "FoodSpawn", zid)
        for i, (x, zz) in enumerate(foods)
    ]))
    kids.append(sensor("MilkRainSpot", (cx, top + 1, cz), (4, 1, 4), "MilkRainSpot", zid))
    kids.append(sensor("BossSpawn", (bsx, top + 0.5, bsz), (4, 1, 4), "BossSpawn", zid))

    rim_y = top + {1: 15, 2: 40, 3: 80}[zid]
    kids.append(folder("Basketball", [
        part("Pole", (hx, (rim_y + top) / 2, hz - 3 * k), (1 * k, rim_y - top + 4 * k, 1 * k), rgb(90, 90, 100), "Metal"),
        part("Backboard", (hx, rim_y + 3 * k, hz - 2.5 * k), (8 * k, 6 * k, 0.5 * k), rgb(255, 255, 255)),
        part("Rim", (hx, rim_y, hz), (0.4 * k, 6 * k, 6 * k), rgb(255, 120, 30), collide=False, shape="Cylinder",
             orient=CYL_UP, transparent=0.2),
        sensor("HoopSensor", (hx, rim_y - 0.5 * k, hz), (4 * k, 1 * k, 4 * k), "Hoop", zid),
        part("BallRack", (hx + 10 * k, top + 1.5 * k, hz + 10 * k), (4 * k, 3 * k, 4 * k), rgb(200, 90, 40), "Wood",
             tags=["BallRack"], attrs={"Zone": zid}),
    ]))

    bar_y = top + 7 * k
    kids.append(folder("PullupBar", [
        part("PostA", (bx - 4 * k, (bar_y + top) / 2, bz), (0.6 * k, bar_y - top, 0.6 * k), rgb(80, 80, 90), "Metal"),
        part("PostB", (bx + 4 * k, (bar_y + top) / 2, bz), (0.6 * k, bar_y - top, 0.6 * k), rgb(80, 80, 90), "Metal"),
        part("Bar", (bx, bar_y, bz), (8 * k, 0.4 * k, 0.4 * k), rgb(200, 200, 210), "Metal", shape="Cylinder",
             tags=["Bar"], attrs={"Zone": zid}),
    ]))

    beds = []
    for i, dx in enumerate((-6, 6)):
        x = ex + dx * k
        beds.append(part(f"Bed{i + 1}", (x, top + 1 * k, ez), (5 * k, 2 * k, 9 * k), rgb(120, 150, 255), "Fabric",
                         tags=["Bed"], attrs={"Zone": zid}))
        beds.append(deco(f"Pillow{i + 1}", (x, top + 2.4 * k, ez - 3.3 * k), (4 * k, 0.8 * k, 2 * k),
                         rgb(255, 255, 255), "Fabric"))
    kids.append(folder("Beds", beds))
    return folder(z["name"], kids)


def gates():
    out = []
    wall = rgb(240, 225, 190)
    out.append(part("Wall1A", (120, 40, -80), (4, 80, 120), wall, "Brick"))
    out.append(part("Wall1B", (120, 40, 80), (4, 80, 120), wall, "Brick"))
    out.append(part("Gate2", (120, 30, 0), (4, 60, 40), rgb(120, 200, 255), "ForceField", transparent=0.2,
                    tags=["ZoneGate"], attrs={"Zone": 2}))
    out.append(part("Gate2Top", (120, 70, 0), (4, 20, 40), wall, "Brick"))
    z0, z1, y0, y1 = 140, 600, 0, 300
    length = math.hypot(z1 - z0, y1 - y0)
    a = math.atan2(y1 - y0, z1 - z0)
    c, s = math.cos(a), math.sin(a)
    rot = [[1, 0, 0], [0, c, s], [0, -s, c]]  # 행 우선: 로컬 Z축 = (0, s, c) → z가 커질수록 올라감
    out.append(part("HikingTrail", (260, (y0 + y1) / 2 - 2 * c, (z0 + z1) / 2), (60, 4, length), rgb(140, 105, 70),
                    "Slate", orient=rot))
    out.append(part("Gate3", (260, 40, 143), (60, 80, 4), rgb(150, 230, 150), "ForceField", transparent=0.2,
                    tags=["ZoneGate"], attrs={"Zone": 3}))
    out.append(sign("TrailSign", (260, 92, 141), (40, 10, 1), "용문산 등산로", rgb(90, 70, 50)))
    return folder("Gates", out)


def lobby():
    board = part("GlobalBoard", (0, 10, -70), (30, 16, 1), rgb(30, 30, 45), tags=["GlobalBoard"])
    spawn = {
        "name": "SpawnLocation", "className": "SpawnLocation",
        "properties": {
            "Anchored": True, "Size": [12, 1, 12],
            "CFrame": {"CFrame": {"position": [0, 0.5, 40], "orientation": ID}},
            "Color": rgb(255, 255, 255), "Material": "Neon", "Duration": 0, "TopSurface": "Smooth",
        },
    }
    return folder("Lobby", [board, spawn])


model = {"className": "Model", "children": [zone_folder(z) for z in ZONES] + [gates(), lobby()]}
here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "..", "map", "BaseMap.model.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(model, f, ensure_ascii=False, indent=1)
print("wrote", os.path.normpath(out))
