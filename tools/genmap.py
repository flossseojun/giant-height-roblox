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
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from osm.zone1 import build_zone1  # noqa: E402

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
    dict(id=1, name="1_양평읍", center=(-180, 0, -80), size=(600, 440), color=rgb(125, 165, 105), material="Grass", k=1),
    dict(id=2, name="2_두물머리", center=(260, 0, 0), size=(280, 280), color=rgb(110, 185, 90), material="Grass", k=3),
    dict(id=3, name="3_용문산", center=(260, 300, 800), size=(400, 400), color=rgb(70, 140, 70), material="Grass", k=6),
    dict(id=4, name="4_밤하늘", center=(260, 800, 1750), size=(500, 500), color=rgb(30, 30, 70), material="SmoothPlastic", k=8),
]
AREAS = {
    1: ((-180, 500, -80), (600, 1100, 440)),
    2: ((260, 500, 0), (280, 1100, 280)),
    3: ((260, 500, 570), (400, 1100, 860)),
    4: ((260, 900, 1500), (500, 1400, 1000)),
}
# 별자리: (id, 이름, 중심 오프셋, 점들) — 점 순서대로 밟기
CONSTELLATIONS = [
    ("bigdipper", "북두칠성", (-130, 0), [(-60, 40), (-20, 40), (-20, 0), (-60, 0), (10, -20), (40, -40), (80, -50)]),
    ("cassiopeia", "카시오페이아", (60, 60), [(-60, 0), (-30, -30), (0, 0), (30, -30), (60, 0)]),
    ("orion", "오리온", (-60, -150), [(-30, 50), (30, 50), (-10, 0), (0, 0), (10, 0), (30, -50), (-30, -50)]),
]
# 보스 자리 (구역 안쪽 빈 곳)
BOSS = {1: (40, -40), 2: (200, 40), 3: (340, 820)}
WATER = rgb(90, 160, 220)


Z1 = None  # 아래에서 build_zone1()로 채움


def ry(yaw):
    """로컬 X축이 (cos yaw, 0, sin yaw)를 향하는 회전 (행 우선)"""
    c, s = math.cos(-yaw), math.sin(-yaw)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def facility_spots(z):
    if z["id"] == 1:
        return Z1["spots"]
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
        pass  # 1구역 장식은 OSM 그룹으로 따로 넣음
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
    elif zid == 4:
        out.append(sign("NightSign", (260, top + 14, 1515), (50, 10, 1), "양평 밤하늘", rgb(40, 40, 90),
                        text_color=rgb(255, 240, 150), faces=("Front", "Back")))
        stars = []
        for i in range(60):
            stars.append(deco(f"Star{i}", (260 + random.uniform(-260, 260), top + random.uniform(40, 220),
                                           1750 + random.uniform(-260, 260)),
                              (3, 3, 3), rgb(255, 245, 190), "Neon", shape="Ball", collide=False))
        out.append(folder("FloatingStars", stars))
        for cid, cname, (ox, oz), pts in CONSTELLATIONS:
            kids = []
            world = [(260 + ox + x, 1750 + oz + z) for x, z in pts]
            for i, (x, zz) in enumerate(world):
                kids.append(part(f"Star{i + 1}", (x, top + 0.8, zz), (1.6, 16, 16), rgb(255, 230, 120), "Neon",
                                 transparent=0.15, collide=False, shape="Cylinder", orient=CYL_UP,
                                 tags=["StarPoint"],
                                 attrs={"Constellation": cid, "Index": i + 1, "Total": len(world),
                                        "DisplayName": cname, "Zone": 4},
                                 extra={"CanTouch": True, "CanQuery": False},
                                 children=[surface_text(str(i + 1), "Right", rgb(60, 40, 120), ppu=8)]))
            for i in range(len(world) - 1):
                (x0, z0), (x1, z1) = world[i], world[i + 1]
                L = math.hypot(x1 - x0, z1 - z0)
                c, sn = (x1 - x0) / L, -(z1 - z0) / L
                kids.append(deco(f"Line{i + 1}", ((x0 + x1) / 2, top + 0.3, (z0 + z1) / 2), (L, 0.4, 1.2),
                                 rgb(180, 170, 255), "Neon", collide=False, orient=[[c, 0, sn], [0, 1, 0], [-sn, 0, c]]))
            xs, zs = [x for x, _ in world], [z for _, z in world]
            avoid.append((min(xs) - 12, max(xs) + 12, min(zs) - 12, max(zs) + 12))
            out.append(folder(cname, kids))
            out.append(sign(f"{cid}Sign", (260 + ox, top + 6, 1750 + oz + max(z for _, z in pts) + 18), (30, 6, 1),
                            cname + " (1번부터 순서대로!)", rgb(40, 40, 90), text_color=rgb(255, 240, 150),
                            faces=("Front", "Back")))
    else:
        # 정상 아래로 계단식 산 몸통 (시내에서 보면 저 멀리 용문산)
        lumps = [((260, 100, 800), 400, rgb(70, 125, 60)), ((150, 40, 720), 260, rgb(78, 135, 66)),
                 ((380, 30, 870), 260, rgb(66, 118, 58)), ((280, 20, 660), 220, rgb(82, 140, 70)),
                 ((200, 10, 930), 220, rgb(74, 128, 62)), ((400, 0, 700), 200, rgb(80, 132, 66))]
        for i, (pos, d, col) in enumerate(lumps):
            out.append(deco(f"Mountain{i}", pos, (d, d, d), col, "Grass", shape="Ball"))
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
    if zid == 1:
        kids = [folder(name, items) for name, items in Z1["groups"].items()]
    else:
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
    avoid += [(hx - pad, hx + pad + 10 * k, hz - pad, hz + pad + 10 * k), (bx - pad, bx + pad, bz - pad, bz + pad),
              (ex - pad, ex + pad, ez - pad, ez + pad), (cx - 8, cx + 8, cz - 8, cz + 8)]
    if zid in BOSS:
        bsx, bsz = BOSS[zid]
        avoid.append((bsx - 12 * k, bsx + 12 * k, bsz - 12 * k, bsz + 12 * k))

    foods, tries = (list(Z1["food"]) if zid == 1 else []), 0
    while zid != 1 and len(foods) < 20 and tries < 5000:
        tries += 1
        x = cx + random.uniform(-0.42, 0.42) * sx
        zz = cz + random.uniform(-0.42, 0.42) * sz
        if any(x0 <= x <= x1 and z0 <= zz <= z1 for x0, x1, z0, z1 in avoid):
            continue
        if any((x - fx) ** 2 + (zz - fz) ** 2 < (0.07 * sx) ** 2 for fx, fz in foods):
            continue
        foods.append((x, zz))
    assert len(foods) == (60 if zid == 1 else 20), f"zone {zid}: only {len(foods)} food spots"
    kids.append(folder("FoodSpawns", [
        sensor(f"FoodSpawn{i + 1}", (x, top + 2 * k, zz), (2 * k, 2 * k, 2 * k), "FoodSpawn", zid)
        for i, (x, zz) in enumerate(foods)
    ]))
    rx, rz = Z1["rain"] if zid == 1 else (cx, cz)
    kids.append(sensor("MilkRainSpot", (rx, top + 1, rz), (4, 1, 4), "MilkRainSpot", zid))
    if zid in BOSS:
        kids.append(sensor("BossSpawn", (bsx, top + 0.5, bsz), (4, 1, 4), "BossSpawn", zid))

    rim_y = top + {1: 8, 2: 24, 3: 48, 4: 70}[zid]  # 점프하면 손이 닿는 높이 (덩크)
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
    # 용문산 → 밤하늘 은하수 다리
    z0, z1, y0, y1 = 1000, 1500, 300, 800
    length = math.hypot(z1 - z0, y1 - y0)
    a = math.atan2(y1 - y0, z1 - z0)
    c, s = math.cos(a), math.sin(a)
    out.append(part("MilkyWayBridge", (260, (y0 + y1) / 2 - 2 * c, (z0 + z1) / 2), (60, 4, length), rgb(170, 150, 255),
                    "Neon", orient=[[1, 0, 0], [0, c, s], [0, -s, c]], transparent=0.15))
    out.append(part("Gate4", (260, 340, 997), (60, 80, 4), rgb(120, 100, 255), "ForceField", transparent=0.2,
                    tags=["ZoneGate"], attrs={"Zone": 4}))
    out.append(sign("MilkyWaySign", (260, 392, 995), (40, 10, 1), "은하수 다리", rgb(40, 40, 90),
                    text_color=rgb(255, 240, 150)))
    return folder("Gates", out)


def lobby():
    (bx1, by1, bz1), (bx2, by2, bz2) = Z1["boards"]
    sx, sz, syaw = Z1["spawn"]
    # 순위판: 정면(Front, 로컬 −Z)이 스폰 쪽을 보게
    face = ry(Z1["board_yaw"] + math.pi / 2)
    board = part("GlobalBoard", (bx1, by1 + 1, bz1), (26, 13, 0.8), rgb(30, 35, 60), tags=["GlobalBoard"], orient=face)
    weekly = part("WeeklyBoard", (bx2, by2 + 1, bz2), (26, 13, 0.8), rgb(60, 35, 60), tags=["WeeklyBoard"], orient=face)
    frames = []
    for i, (bx, by, bz) in enumerate(((bx1, by1 + 1, bz1), (bx2, by2 + 1, bz2))):
        frames.append(deco(f"BoardPost{i}", (bx, (by - 6.5) / 2, bz), (1.2, by - 6.5, 1.2), rgb(120, 85, 55), "Wood"))
    ax, az = (bx1 + bx2) / 2, (bz1 + bz2) / 2
    frames.append(deco("OsmCredit", (ax, 3, az), (10, 3, 0.4), rgb(255, 255, 255), orient=face,
                       children=[surface_text("지도 데이터 © OpenStreetMap contributors", f, rgb(40, 40, 40), ppu=20)
                                 for f in ("Front", "Back")]))
    # 스폰이 역을 바라봄: SpawnLocation 정면(로컬 −Z)을 syaw 방향으로
    spawn = {
        "name": "SpawnLocation", "className": "SpawnLocation",
        "properties": {
            "Anchored": True, "Size": [10, 1, 10],
            "CFrame": {"CFrame": {"position": [sx, 0.5, sz], "orientation": ry(syaw + math.pi / 2)}},
            "Color": rgb(230, 230, 230), "Material": "SmoothPlastic", "Transparency": 0.6, "Duration": 0,
            "TopSurface": "Smooth",
        },
    }
    return folder("Lobby", [board, weekly, spawn] + frames)


def translate(node, dx, dz):
    p = node.get("properties", {})
    if "CFrame" in p:
        pos = p["CFrame"]["CFrame"]["position"]
        p["CFrame"]["CFrame"]["position"] = [pos[0] + dx, pos[1], pos[2] + dz]
    for c in node.get("children", []):
        translate(c, dx, dz)


def gate2_and_link():
    """1구역 서쪽 큰길 끝의 2구역 문 + 2구역까지 이어지는 길"""
    gx, gz, gw, gyaw = Z1["gate2"]
    width = max(gw + 12, 40)
    out = [part("Gate2", (gx, 30, gz), (4, 60, width), rgb(120, 200, 255), "ForceField", transparent=0.2,
                tags=["ZoneGate"], attrs={"Zone": 2}),
           part("Gate2Top", (gx, 64, gz), (4, 8, width + 8), rgb(240, 225, 190), "Brick"),
           part("LinkRoad", (gx - LINK / 2, -2, gz), (LINK + 4, 4, width), rgb(70, 70, 75), "Asphalt")]
    for s_ in (-1, 1):
        out.append(part(f"Gate2Pillar{s_}", (gx, 34, gz + s_ * (width / 2 + 2)), (4, 68, 4), rgb(240, 225, 190), "Brick"))
    return out


LINK = 130  # 1구역 서쪽 끝 ~ 2구역 동쪽 끝 사이 길이 (4구역이 2구역보다 동쪽으로 110 더 넓어서 겹치지 않게)

Z1 = build_zone1({"part": part, "deco": deco, "sign": sign, "folder": folder, "surface_text": surface_text,
                  "rgb": rgb})
x0, x1, z0, z1 = Z1["bounds"]
ZONES[0]["center"] = ((x0 + x1) / 2, 0, (z0 + z1) / 2)
ZONES[0]["size"] = (x1 - x0, z1 - z0)
AREAS[1] = Z1["zone_area"]
BOSS[1] = Z1["boss"]

# 2·3·4구역은 디자인 그대로, 1구역 서쪽으로 이동 (2구역 동쪽 끝 x=400 → 1구역 서쪽 끝 − LINK, 2구역 중심 z → 문 z)
DX = x0 - LINK - 400
DZ = Z1["gate2"][1] - 0
others = [zone_folder(z) for z in ZONES[1:]]
g = gates()
for f in others + [g]:
    translate(f, DX, DZ)
g["children"] += gate2_and_link()
model = {"className": "Model", "children": [zone_folder(ZONES[0])] + others + [g, lobby()]}

# 스튜디오용 지형 스크립트 (하천 + 바닥 빈칸 잔디)
terrain = ["-- 자동 생성: tools/genmap.py (1구역 바닥 빈칸 잔디 + 양근천·남한강 물)", "local T = workspace.Terrain"]
for i, (hx, hz) in enumerate(Z1["holes"]):
    terrain.append(f"T:FillBlock(CFrame.new({hx:.1f}, -3.5, {hz:.1f}), Vector3.new(32, 6, 32), Enum.Material.Grass)")
    if i % 40 == 39:
        terrain.append("task.wait()")
terrain.append(Z1["water_luau"])
tpath = os.path.join(os.path.dirname(os.path.abspath(__file__)), "studio", "terrain_water.luau")
os.makedirs(os.path.dirname(tpath), exist_ok=True)
open(tpath, "w", encoding="utf-8").write("\n".join(terrain) + "\n")

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "..", "map", "BaseMap.model.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(model, f, ensure_ascii=False, indent=1)
print("wrote", os.path.normpath(out))
