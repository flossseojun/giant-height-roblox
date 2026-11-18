#!/usr/bin/env python3
"""기본 맵(map/BaseMap.model.json) 생성기.

실행: python3 tools/genmap.py
그다음: rojo build map.project.json -o build/BaseMap.rbxm
좌표 단위는 스터드. 바닥 윗면 y=0(1·2구역), y=300(3구역).
"""
import json
import math
import os
import random

random.seed(7)
ID = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


def rgb(r, g, b):
    return [r / 255, g / 255, b / 255]


def part(name, pos, size, color=None, material="SmoothPlastic", transparent=0,
         collide=True, tags=None, attrs=None, cls="Part", orient=None, shape=None, extra=None):
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
    return node


def sensor(name, pos, size, tag, zone):
    return part(name, pos, size, transparent=1, collide=False, tags=[tag], attrs={"Zone": zone},
                extra={"CanTouch": True, "CanQuery": False})


def folder(name, children):
    return {"name": name, "className": "Folder", "children": children}


ZONES = [
    # id, 이름, 바닥 중심, 바닥 크기(x,z), 바닥 높이, 색, 재질, 시설 배율
    dict(id=1, name="1_놀이터", center=(0, 0, 0), size=(240, 240), color=rgb(120, 200, 95), material="Grass", k=1),
    dict(id=2, name="2_운동장", center=(260, 0, 0), size=(280, 280), color=rgb(215, 150, 85), material="Ground", k=3),
    dict(id=3, name="3_구름위", center=(260, 300, 800), size=(400, 400), color=rgb(245, 250, 255), material="Snow", k=6),
]

AREAS = {  # (중심, 크기) — 서버가 "지금 어느 구역에 있나"를 판단하는 투명 상자
    1: ((0, 500, 0), (240, 1100, 240)),
    2: ((260, 500, 0), (280, 1100, 280)),
    3: ((260, 500, 570), (400, 1100, 860)),
}


def zone_folder(z):
    cx, top, cz = z["center"]
    sx, sz = z["size"]
    k = z["k"]
    zid = z["id"]
    kids = [part("Floor", (cx, top - 2, cz), (sx, 4, sz), z["color"], z["material"])]

    a_pos, a_size = AREAS[zid]
    kids.append(sensor("ZoneArea", a_pos, a_size, "ZoneArea", zid))

    # 음식 스폰 20개: 가장자리 피해서 흩뿌림 (시설 근처 피하기)
    foods = []
    tries = 0
    while len(foods) < 20 and tries < 2000:
        tries += 1
        x = cx + random.uniform(-0.42, 0.42) * sx
        zz = cz + random.uniform(-0.42, 0.42) * sz
        if any((x - fx) ** 2 + (zz - fz) ** 2 < (0.08 * sx) ** 2 for fx, fz in foods):
            continue
        foods.append((x, zz))
    kids.append(folder("FoodSpawns", [
        sensor(f"FoodSpawn{i + 1}", (x, top + 2 * k, zz), (2 * k, 2 * k, 2 * k), "FoodSpawn", zid)
        for i, (x, zz) in enumerate(foods)
    ]))

    # 우유 비 중심
    kids.append(sensor("MilkRainSpot", (cx, top + 1, cz), (4, 1, 4), "MilkRainSpot", zid))

    # 농구 골대: 기둥 + 백보드 + 림 + 센서. 림 높이는 구역마다 높아짐
    hx, hz = cx - 0.3 * sx, cz + 0.3 * sz
    rim_y = top + {1: 15, 2: 40, 3: 80}[zid]
    hoop = [
        part("Pole", (hx, top + (rim_y - top) / 2, hz - 3 * k), (1 * k, rim_y - top + 4 * k, 1 * k), rgb(90, 90, 100), "Metal"),
        part("Backboard", (hx, rim_y + 3 * k, hz - 2.5 * k), (8 * k, 6 * k, 0.5 * k), rgb(255, 255, 255)),
        part("Rim", (hx, rim_y, hz), (0.4 * k, 6 * k, 6 * k), rgb(255, 120, 30), collide=False,
             shape="Cylinder", orient=[[0, -1, 0], [1, 0, 0], [0, 0, 1]], transparent=0.2),
        sensor("HoopSensor", (hx, rim_y - 0.5 * k, hz), (4 * k, 1 * k, 4 * k), "Hoop", zid),
    ]
    rack = part("BallRack", (hx + 10 * k, top + 1.5 * k, hz + 10 * k), (4 * k, 3 * k, 4 * k), rgb(200, 90, 40), "Wood",
                tags=["BallRack"], attrs={"Zone": zid})
    kids.append(folder("Basketball", hoop + [rack]))

    # 철봉: 기둥 2개 + 가로대(태그)
    bx, bz = cx + 0.3 * sx, cz + 0.3 * sz
    bar_y = top + 7 * k
    kids.append(folder("PullupBar", [
        part("PostA", (bx - 4 * k, top + bar_y / 2 - top / 2, bz), (0.6 * k, bar_y - top, 0.6 * k), rgb(80, 80, 90), "Metal"),
        part("PostB", (bx + 4 * k, top + bar_y / 2 - top / 2, bz), (0.6 * k, bar_y - top, 0.6 * k), rgb(80, 80, 90), "Metal"),
        part("Bar", (bx, bar_y, bz), (8 * k, 0.4 * k, 0.4 * k), rgb(200, 200, 210), "Metal", shape="Cylinder",
             tags=["Bar"], attrs={"Zone": zid}),
    ]))

    # 침대 2개
    beds = []
    for i, dx in enumerate((-6, 6)):
        ex, ez = cx + 0.3 * sx + dx * k, cz - 0.3 * sz
        beds.append(part(f"Bed{i + 1}", (ex, top + 1 * k, ez), (5 * k, 2 * k, 9 * k), rgb(120, 150, 255), "Fabric",
                         tags=["Bed"], attrs={"Zone": zid}))
        beds.append(part(f"Pillow{i + 1}", (ex, top + 2.4 * k, ez - 3.3 * k), (4 * k, 0.8 * k, 2 * k), rgb(255, 255, 255),
                         "Fabric"))
    kids.append(folder("Beds", beds))

    return folder(z["name"], kids)


def gates():
    out = []
    wall = rgb(250, 230, 120)
    # 1 → 2구역: x=120 경계 벽, 가운데 문
    out.append(part("Wall1A", (120, 40, -80), (4, 80, 120), wall, "Brick"))
    out.append(part("Wall1B", (120, 40, 80), (4, 80, 120), wall, "Brick"))
    out.append(part("Gate2", (120, 30, 0), (4, 60, 40), rgb(255, 90, 160), "ForceField", transparent=0.2,
                    tags=["ZoneGate"], attrs={"Zone": 2}))
    out.append(part("Gate2Top", (120, 70, 0), (4, 20, 40), wall, "Brick"))
    # 2 → 3구역: 무지개 다리 + 다리 입구 문
    z0, z1, y0, y1 = 140, 600, 0, 300
    length = math.hypot(z1 - z0, y1 - y0)
    a = math.atan2(y1 - y0, z1 - z0)  # x축 기준 회전
    c, s = math.cos(a), math.sin(a)
    rot = [[1, 0, 0], [0, c, s], [0, -s, c]]  # 행 우선: 로컬 Z축 = (0, s, c) → z가 커질수록 올라감
    out.append(part("RainbowBridge", (260, (y0 + y1) / 2 - 2 * c, (z0 + z1) / 2), (60, 4, length), rgb(255, 170, 220),
                    "Neon", orient=rot, transparent=0.1))
    out.append(part("Gate3", (260, 40, 143), (60, 80, 4), rgb(140, 120, 255), "ForceField", transparent=0.2,
                    tags=["ZoneGate"], attrs={"Zone": 3}))
    return folder("Gates", out)


def lobby():
    board = part("GlobalBoard", (0, 10, -70), (30, 16, 1), rgb(30, 30, 45), "SmoothPlastic", tags=["GlobalBoard"])
    spawn = {
        "name": "SpawnLocation",
        "className": "SpawnLocation",
        "properties": {
            "Anchored": True,
            "Size": [12, 1, 12],
            "CFrame": {"CFrame": {"position": [0, 0.5, 40], "orientation": ID}},
            "Color": rgb(255, 255, 255),
            "Material": "Neon",
            "Duration": 0,
            "TopSurface": "Smooth",
        },
    }
    return folder("Lobby", [board, spawn])


model = {
    "className": "Model",
    "children": [zone_folder(z) for z in ZONES] + [gates(), lobby()],
}

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "..", "map", "BaseMap.model.json")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    json.dump(model, f, ensure_ascii=False, indent=1)
print("wrote", os.path.normpath(out))
