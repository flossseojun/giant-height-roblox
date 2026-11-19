"""랜드마크 상세: 양평역, 정류장 A, 역전길 로터리, 오스타 코아루, 물맑은시장.
위치는 모두 OSM 윤곽에서 가져오고, 모양은 일반적인 형태(사진을 받으면 맞춰 수정).
"""
import math

from osm.buildings import box
from osm.project import FLOOR
from osm.rail_water import DECK_Y


def rgb(r, g, b):
    return (r / 255, g / 255, b / 255)


WHITE, PANEL, NAVY = rgb(244, 245, 246), rgb(222, 226, 230), rgb(32, 62, 120)
GLASS, DGLASS, TEAL = rgb(120, 168, 200), rgb(48, 70, 92), rgb(40, 170, 150)
BLUEGLASS = rgb(40, 120, 190)
METAL, GREEN, ORANGE = rgb(150, 152, 158), rgb(96, 160, 84), rgb(255, 160, 40)


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def _len(v):
    return math.hypot(v[0], v[1])


def _unit(v):
    L = _len(v) or 1.0
    return (v[0] / L, v[1] / L)


def quad_frame(A, B, C, D):
    """사각형 A-B-C-D(A→B 짧은 변, A→D 긴 변) → 중심, 긴 축 단위벡터, 짧은 축 단위벡터, 길이, 폭, yaw"""
    cx = (A[0] + B[0] + C[0] + D[0]) / 4
    cz = (A[1] + B[1] + C[1] + D[1]) / 4
    long_v = _unit((((D[0] - A[0]) + (C[0] - B[0])) / 2, ((D[1] - A[1]) + (C[1] - B[1])) / 2))
    L = (_len(_sub(D, A)) + _len(_sub(C, B))) / 2
    W = (_len(_sub(B, A)) + _len(_sub(C, D))) / 2
    short_v = (-long_v[1], long_v[0])
    return (cx, cz), long_v, short_v, L, W, math.atan2(long_v[1], long_v[0])


def face_toward(yaw, normal):
    """로컬 Z축(= (-sin yaw, cos yaw))과 normal이 같은 쪽이면 'Back', 아니면 'Front'"""
    z = (-math.sin(yaw), math.cos(yaw))
    return "Back" if z[0] * normal[0] + z[1] * normal[1] > 0 else "Front"


def labeled(spec, text, face, fg=(1, 1, 1), ppu=10):
    spec["label"] = (text, face, fg, ppu)
    return spec


# ------------------------------------------------------------------ 양평역
def station(pts, toward):
    """pts: 역 윤곽(스터드). toward: 입구가 바라볼 점(로터리 중심)."""
    P = [tuple(p) for p in pts]
    A, B, C, D = P[0], P[10], P[3], P[2]  # 서쪽 역사 날개: (-127,-41),(-106,-53),(-36,59),(-59,73)
    E = [P[4], P[5], P[6], P[7]]  # 승강장 위 대합실: (-40,52),(44,3),(10,-53),(-53,-16)
    out = []
    (cx, cz), lv, sv, L, W, yaw = quad_frame(A, B, C, D)
    n = sv if (toward[0] - cx) * sv[0] + (toward[1] - cz) * sv[1] > 0 else (-sv[0], -sv[1])
    face = face_toward(yaw, n)
    H = DECK_Y + 26  # 대합실 지붕 높이에 맞춘 3층 높이
    # 사진: 왼쪽은 흰 벽 + 큰 회색 "양평역" 글자, 오른쪽은 파란 유리 상자, 윗부분 흰 루버
    out.append(box("WingBody", cx, 0, cz, L, H, W, yaw, WHITE))
    out.append(box("WingRoof", cx, H, cz, L + 2, 1.2, W + 2, yaw, PANEL, "Metal"))
    left = (-n[1], n[0])  # 로터리에서 역을 바라볼 때 왼쪽
    sgn = 1 if left[0] * lv[0] + left[1] * lv[1] > 0 else -1
    gx, gz = cx + n[0] * (W / 2 + 0.3), cz + n[1] * (W / 2 + 0.3)
    glass_c = -sgn * L * 0.15  # 유리는 오른쪽 70%
    gL = L * 0.7 - 2
    out.append(box("WingGlass", gx + lv[0] * glass_c, 1, gz + lv[1] * glass_c, gL, H - 7, 0.5, yaw, BLUEGLASS, "Glass",
                   transparency=0.1))
    k = 0
    t = glass_c - gL / 2 + 6
    while t < glass_c + gL / 2 - 2:
        out.append(box(f"Mullion{k}", gx + lv[0] * t + n[0] * 0.3, 1, gz + lv[1] * t + n[1] * 0.3, 0.5, H - 7, 0.5, yaw,
                       rgb(200, 215, 228), "Metal"))
        t += 6
        k += 1
    for f, y in enumerate((9, 18, 27, 36)):
        out.append(box(f"GlassBand{f}", gx + lv[0] * glass_c + n[0] * 0.35, y, gz + lv[1] * glass_c + n[1] * 0.35, gL,
                       0.5, 0.5, yaw, rgb(200, 215, 228), "Metal"))
    for f in range(3):  # 꼭대기 흰 루버
        out.append(box(f"Louver{f}", gx + lv[0] * glass_c + n[0] * 0.8, H - 5.5 + f * 1.6,
                       gz + lv[1] * glass_c + n[1] * 0.8, gL, 0.6, 1.2, yaw, WHITE, "Metal"))
    # 왼쪽 흰 벽 위 역 이름(회색 글자)
    sc = sgn * L * 0.35
    sx_, sz_ = cx + lv[0] * sc + n[0] * (W / 2 + 0.6), cz + lv[1] * sc + n[1] * (W / 2 + 0.6)
    out.append(labeled(box("NameBand", sx_, H - 13, sz_, L * 0.28, 10, 0.4, yaw, WHITE), "양평역", face,
                       fg=rgb(95, 100, 108), ppu=6))
    out.append(labeled(box("NameBandEn", sx_, H - 16.5, sz_, L * 0.28, 3, 0.45, yaw, WHITE), "Yangpyeong Station",
                       face, fg=rgb(95, 100, 108), ppu=14))
    # 역 앞 가로수 (출입구 자리는 비움)
    for i, tt in enumerate((-0.44, -0.32, 0.4)):
        tx = cx - lv[0] * sgn * L * tt + n[0] * (W / 2 + 5)
        tz = cz - lv[1] * sgn * L * tt + n[1] * (W / 2 + 5)
        out.append(box(f"TreeTrunk{i}", tx, 0, tz, 0.9, 8, 0.9, yaw, rgb(110, 80, 50), "Wood"))
        out.append({"name": f"TreeCrown{i}", "cls": "Part", "shape": "Ball", "pos": (tx, 12, tz), "size": (7, 9, 7),
                    "rot": [[1, 0, 0], [0, 1, 0], [0, 0, 1]], "color": rgb(70, 140, 60), "material": "Grass",
                    "collide": False})
    # 출입구: 로터리 쪽 남쪽 부분에 어두운 유리문 3개 + 캐노피 + 기둥
    ex, ez = cx - lv[0] * sgn * (L * 0.18), cz - lv[1] * sgn * (L * 0.18)
    for i, off in enumerate((-10, 0, 10)):
        out.append(box(f"Door{i}", ex + lv[0] * off + n[0] * (W / 2 + 0.6), 0, ez + lv[1] * off + n[1] * (W / 2 + 0.6),
                       7, 9, 0.6, yaw, DGLASS, "Glass", collide=False))
    out.append(box("Canopy", ex + n[0] * (W / 2 + 6), 11, ez + n[1] * (W / 2 + 6), 40, 1, 12, yaw, WHITE, "Metal"))
    for i, off in enumerate((-19, 19)):
        out.append(box(f"CanopyPole{i}", ex + lv[0] * off + n[0] * (W / 2 + 11), 0, ez + lv[1] * off + n[1] * (W / 2 + 11),
                       0.8, 11, 0.8, yaw, WHITE, "Metal"))
    out.append(box("EntranceSteps", ex + n[0] * (W / 2 + 3), 0, ez + n[1] * (W / 2 + 3), 34, 0.8, 6, yaw,
                   rgb(200, 198, 192), "Slate"))
    # "양평역앞에서" 표지석 (입구 왼쪽 앞)
    mx_ = ex + lv[0] * sgn * 30 + n[0] * (W / 2 + 12)
    mz_ = ez + lv[1] * sgn * 30 + n[1] * (W / 2 + 12)
    out.append(box("MonumentBase", mx_, 0, mz_, 4.5, 0.8, 3, yaw, rgb(170, 168, 160), "Slate"))
    out.append(labeled(box("Monument", mx_, 0.8, mz_, 3, 10, 1.8, yaw, rgb(178, 176, 168), "Slate"),
                       "양\n평\n역\n앞\n에\n서", face, fg=rgb(60, 60, 64), ppu=16))
    # 승강장 위 대합실(공중층): 유리 상자 + 지붕 + 기둥, 남북 면에 역 이름
    (ccx, ccz), clv, csv, CL, CW, cyaw = quad_frame(E[3], E[0], E[1], E[2])
    y0 = DECK_Y + 11
    out.append(box("ConcourseFloor", ccx, y0 - 1, ccz, CL, 1.5, CW, cyaw, PANEL))
    out.append(box("ConcourseGlass", ccx, y0, ccz, CL, H - y0, CW, cyaw, GLASS, "Glass", transparency=0.25))
    out.append(box("ConcourseRoof", ccx, H, ccz, CL + 4, 1.2, CW + 4, cyaw, WHITE, "Metal"))
    for i, (u, v) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        px = ccx + clv[0] * u * (CL / 2 - 2) + csv[0] * v * (CW / 2 - 2)
        pz = ccz + clv[1] * u * (CL / 2 - 2) + csv[1] * v * (CW / 2 - 2)
        out.append(box(f"ConcourseColumn{i}", px, 0, pz, 2.5, y0 - 1, 2.5, cyaw, WHITE, "Concrete"))
    for i, sgn in enumerate((-1, 1)):
        nx_, nz_ = clv[0] * sgn, clv[1] * sgn
        px, pz = ccx + nx_ * (CL / 2 + 0.4), ccz + nz_ * (CL / 2 + 0.4)
        f = "Right" if sgn > 0 else "Left"
        out.append(labeled(box(f"ConcourseName{i}", px, H - 7, pz, 0.6, 6, CW * 0.7, cyaw, NAVY), "양평역  Yangpyeong", f,
                           ppu=8))
    return out


# ------------------------------------------------------------------ 정류장 A
def bus_stop(sx, sz, road_dir, road_side):
    """sx,sz: 정류장 중심(스폰). road_dir: 도로 방향 단위벡터. road_side: 정류장에서 도로 쪽 단위벡터."""
    yaw = math.atan2(road_dir[1], road_dir[0])
    face_road = face_toward(yaw, road_side)
    out = []

    def at(u, v):  # u: 도로 방향, v: 도로 쪽
        return sx + road_dir[0] * u + road_side[0] * v, sz + road_dir[1] * u + road_side[1] * v

    x, z = at(0, -1.5)
    out.append(box("StopRoof", x, 9, z, 16, 0.5, 6, yaw, rgb(60, 70, 85), "Metal"))
    ex, ez = at(0, 1.4)
    out.append(box("StopRoofEdge", ex, 8.8, ez, 16.2, 0.5, 0.3, yaw, TEAL, "SmoothPlastic"))
    for i, u in enumerate((-7.5, 7.5)):
        px, pz = at(u, -4)
        out.append(box(f"StopPost{i}", px, 0, pz, 0.5, 9, 0.5, yaw, METAL, "Metal"))
    bx, bz = at(0, -4)
    out.append(box("StopBackGlass", bx, 1, bz, 15, 6.5, 0.3, yaw, GLASS, "Glass", transparency=0.45))
    adx, adz = at(4.5, -4.1)
    out.append(labeled(box("StopAd", adx, 1.5, adz, 4, 5.5, 0.35, yaw, rgb(250, 250, 250)),
                       "양평 물맑은시장\n3·8일 장날", face_road, fg=(0.2, 0.3, 0.5), ppu=20))
    sx2, sz2 = at(7.5, -1.5)  # 역 반대쪽 끝 (역 쪽 시야를 막지 않게)
    out.append(box("StopSideGlass", sx2, 1, sz2, 0.3, 6.5, 4.5, yaw, GLASS, "Glass", transparency=0.45))
    ux, uz = at(-1, -3)
    out.append(box("StopBench", ux, 1.6, uz, 9, 0.5, 1.6, yaw, rgb(150, 105, 65), "Wood"))
    out.append(box("StopBenchLegs", ux, 0, uz, 8, 1.6, 1, yaw, METAL, "Metal", transparency=0.3, collide=False))
    # 정류장 표지판 기둥 + 정류장 이름 + 버스 도착 안내기
    px, pz = at(9.5, 0.5)
    out.append(box("StopSignPole", px, 0, pz, 0.4, 11, 0.4, yaw, METAL, "Metal"))
    out.append(labeled(box("StopSign", px, 8.5, pz, 3.6, 2.4, 0.3, yaw, rgb(30, 110, 200)), "양평역", face_road, ppu=24))
    out.append(labeled(box("StopSignEn", px, 7.2, pz, 3.6, 0.9, 0.3, yaw, rgb(30, 110, 200)), "Yangpyeong Stn.",
                       face_road, ppu=24))
    ix, iz = at(0, -1.5)
    out.append(labeled(box("BusInfoLED", ix, 7.2, iz, 6, 1.4, 0.4, yaw, rgb(20, 20, 24)), "버스 곧 도착",
                       face_road, fg=(1, 0.65, 0.15), ppu=24))
    # 점자 블록 + 경계석
    tx, tz = at(0, 3)
    out.append(box("TactilePaving", tx, 0.3, tz, 18, 0.08, 1.2, yaw, rgb(250, 210, 40), "SmoothPlastic"))
    cx, cz = at(0, 5)
    out.append(box("Curb", cx, 0, cz, 22, 0.55, 0.6, yaw, rgb(205, 205, 200), "Concrete"))
    return out


# ------------------------------------------------------------------ 역전길 로터리
def roundabout(cx, cz, approaches):
    """approaches: [(방향 단위벡터, 도로폭)] — 로터리에서 나가는 도로들"""
    out = [
        {"name": "IslandCurb", "cls": "Part", "shape": "Cylinder", "pos": (cx, 0.35, cz), "size": (0.7, 15, 15),
         "rot": [[0, -1, 0], [1, 0, 0], [0, 0, 1]], "color": rgb(205, 205, 200), "material": "Concrete"},
        {"name": "IslandGrass", "cls": "Part", "shape": "Cylinder", "pos": (cx, 0.75, cz), "size": (0.2, 13.5, 13.5),
         "rot": [[0, -1, 0], [1, 0, 0], [0, 0, 1]], "color": GREEN, "material": "Grass"},
    ]
    for i in range(10):
        a = i / 10 * math.tau
        out.append({"name": f"Flower{i}", "cls": "Part", "shape": "Ball",
                    "pos": (cx + math.cos(a) * 5.2, 1.4, cz + math.sin(a) * 5.2), "size": (1.4, 1.4, 1.4),
                    "rot": [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
                    "color": [rgb(255, 120, 150), rgb(255, 215, 80)][i % 2], "material": "SmoothPlastic",
                    "collide": False})
    out.append(box("IslandTreeTrunk", cx, 0.8, cz, 1, 6, 1, 0, rgb(110, 75, 45), "Wood"))
    out.append({"name": "IslandTreeCrown", "cls": "Part", "shape": "Ball", "pos": (cx, 9, cz), "size": (8, 8, 8),
                "rot": [[1, 0, 0], [0, 1, 0], [0, 0, 1]], "color": rgb(80, 150, 70), "material": "Grass",
                "collide": False})
    # 진입로마다 횡단보도와 정지선
    for j, (d, width) in enumerate(approaches):
        yaw = math.atan2(d[1], d[0])
        across = (-d[1], d[0])
        dist = 24
        k = int(width // 2.6)
        for s in range(k):
            off = -width / 2 + 1.3 + s * 2.6
            x = cx + d[0] * dist + across[0] * off
            z = cz + d[1] * dist + across[1] * off
            out.append(box(f"Zebra{j}_{s}", x, 0.24, z, 5, 0.05, 1.3, yaw, WHITE, "SmoothPlastic", collide=False))
        x, z = cx + d[0] * (dist + 4.5), cz + d[1] * (dist + 4.5)
        out.append(box(f"StopLine{j}", x, 0.24, z, 0.6, 0.05, width, yaw, WHITE, "SmoothPlastic", collide=False))
    return out


# ------------------------------------------------------------------ 오스타 코아루
def ostar(pts, toward, floors=38):
    P = [tuple(p) for p in pts[:-1]]
    cx = sum(p[0] for p in P) / len(P)
    cz = sum(p[1] for p in P) / len(P)
    H = floors * FLOOR
    # 정류장 쪽을 보는 가장 긴 변에 단지 이름 간판과 세로 장식 띠
    best = None
    for i in range(len(P)):
        a, b = P[i], P[(i + 1) % len(P)]
        mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        score = _len(_sub(b, a)) - 0.2 * math.hypot(mx - toward[0], mz - toward[1])
        if best is None or score > best[0]:
            best = (score, a, b, mx, mz)
    _, a, b, mx, mz = best
    ev = _unit(_sub(b, a))
    yaw = math.atan2(ev[1], ev[0])
    nrm = (-ev[1], ev[0])
    if (mx - cx) * nrm[0] + (mz - cz) * nrm[1] < 0:
        nrm = (-nrm[0], -nrm[1])
    face = face_toward(yaw, nrm)
    L = _len(_sub(b, a))
    out = [labeled(box("OstarName", mx + nrm[0] * 0.8, H - 18, mz + nrm[1] * 0.8, min(L * 0.8, 34), 7, 0.5, yaw, NAVY),
                   "오스타 코아루", face, ppu=8)]
    for i, t in enumerate((-0.3, 0.3)):
        out.append(box(f"OstarStripe{i}", mx + ev[0] * L * t + nrm[0] * 0.7, 2, mz + ev[1] * L * t + nrm[1] * 0.7,
                       2, H - 24, 0.4, yaw, rgb(70, 130, 190), "Glass"))
    out.append(box("OstarCrown", cx, H, cz, 18, 10, 18, yaw, rgb(70, 110, 160), "Glass", transparency=0.1))
    out.append(box("OstarCrownTop", cx, H + 10, cz, 20, 1, 20, yaw, WHITE, "Metal"))
    return out


# ------------------------------------------------------------------ 물맑은시장 (양평시장1길 거리 시장)
def _ball(name, x, y, z, d, color, material="SmoothPlastic", collide=False):
    return {"name": name, "cls": "Part", "shape": "Ball", "pos": (x, y, z), "size": (d, d, d),
            "rot": [[1, 0, 0], [0, 1, 0], [0, 0, 1]], "color": color, "material": material, "collide": collide}


UP_ROT = [[0, -1, 0], [1, 0, 0], [0, 0, 1]]  # 원기둥 축(로컬 X)을 위로


def _disc(name, x, y, z, h, d, color, material="Fabric", collide=False):
    return {"name": name, "cls": "Part", "shape": "Cylinder", "pos": (x, y, z), "size": (h, d, d), "rot": UP_ROT,
            "color": color, "material": material, "collide": collide}


SHOP_NAMES = ["떡집", "국밥", "과일", "채소", "족발", "분식", "방앗간", "건어물", "순대", "반찬", "정육점", "생선"]
SHOP_COLORS = [rgb(200, 40, 40), rgb(40, 90, 170), rgb(30, 140, 80), rgb(120, 60, 150), rgb(230, 120, 30),
               rgb(20, 20, 24)]


def market_gate(j, p, d, street_w, text="시장1길"):
    """사진의 '시장1길' 문: 초록 기둥, 흰 간판 상자, 위에 파란 반원 + 흰 루버 + 별"""
    n = (-d[1], d[0])
    yaw = math.atan2(d[1], d[0])
    out = []
    half = street_w / 2 + 2
    PG, BL = rgb(50, 170, 120), rgb(40, 90, 200)
    for s in (-1, 1):
        out.append(box(f"Gate{j}Pillar{s}", p[0] + n[0] * s * half, 0, p[1] + n[1] * s * half, 2.2, 16, 2.2, yaw, PG,
                       "SmoothPlastic"))
    out.append(box(f"Gate{j}InnerArch", p[0] + d[0] * 1.2, 13.5, p[1] + d[1] * 1.2, 0.8, 1.2, street_w + 2, yaw,
                   rgb(40, 160, 150), "SmoothPlastic", collide=False))
    R = half + 1
    out.append(_cyl_h(f"Gate{j}Arch", p[0], 27, p[1], 1.6, R * 2, yaw, BL))
    out.append(_cyl_h(f"Gate{j}Louver", p[0], 27, p[1], 1.9, R * 1.55, yaw, rgb(225, 228, 232), "Metal"))
    for k in range(5):  # 별
        a = math.radians(30 + k * 30)
        for sd in (-1, 1):
            out.append(_ball(f"Gate{j}Star{k}{sd}", p[0] + n[0] * math.cos(a) * R * 0.88 + d[0] * sd * 0.9,
                             27 + math.sin(a) * R * 0.88, p[1] + n[1] * math.cos(a) * R * 0.88 + d[1] * sd * 0.9, 1.1,
                             rgb(255, 215, 70)))
    out.append(box(f"Gate{j}Trim", p[0], 26.8, p[1], 2.6, 0.8, R * 2 + 1, yaw, BL, "SmoothPlastic"))
    out.append(labeled(box(f"Gate{j}Sign", p[0], 15, p[1], 2.2, 12, R * 2, yaw, rgb(246, 244, 238),
                           "SmoothPlastic"), text, "Left", fg=rgb(25, 25, 30), ppu=6))
    out.append(labeled(box(f"Gate{j}SignB", p[0], 15, p[1], 2.25, 12, R * 2 - 0.1, yaw, rgb(246, 244, 238),
                           "SmoothPlastic"), text, "Right", fg=rgb(25, 25, 30), ppu=6))
    out.append(box(f"Gate{j}SignTrim", p[0], 14.6, p[1], 2.4, 0.6, R * 2 + 1, yaw, rgb(250, 200, 40), "SmoothPlastic"))
    return out


def _cyl_h(name, x, yc, z, thick, dia, yaw, color, material="SmoothPlastic"):
    """축이 길 방향(수평)인 원기둥 — 아래 절반은 간판 상자에 묻힘"""
    return {"name": name, "cls": "Part", "shape": "Cylinder", "pos": (x, yc, z),
            "size": (thick, dia, dia), "rot": box("t", 0, 0, 0, 1, 1, 1, yaw, WHITE)["rot"], "color": color,
            "material": material, "collide": False}


def market(street_pts):
    """street_pts: 장터 길 중심선(서→동).
    0..n-2 구간: 지붕 덮인 '시장1길' 아케이드(양 끝 문) — 상점 간판 + 노점.
    마지막 구간: 지붕 없는 장터 — 무지개 파라솔, 흰 천막, 나무 데크, 나무통 화분, 돌 벤치."""
    out = []
    goods = [rgb(90, 170, 60), rgb(230, 70, 50), rgb(250, 170, 40), rgb(150, 60, 140), rgb(240, 230, 200)]
    STREET_W = 16
    t = 0
    covered = len(street_pts) - 2
    for i in range(len(street_pts) - 1):
        a, b = street_pts[i], street_pts[i + 1]
        d = _unit(_sub(b, a))
        n = (-d[1], d[0])
        L = _len(_sub(b, a))
        yaw = math.atan2(d[1], d[0])
        mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2

        def at(u, v, d=d, n=n, a=a):
            return a[0] + d[0] * u + n[0] * v, a[1] + d[1] * u + n[1] * v

        if i < covered:
            # 아케이드 지붕(유리 박공) + 철골
            for s, ang in ((-1, 20), (1, -20)):
                c, si = math.cos(math.radians(ang)), math.sin(math.radians(ang))
                rot = box("tmp", 0, 0, 0, 1, 1, 1, yaw, WHITE)["rot"]
                tilt = [[1, 0, 0], [0, c, -si], [0, si, c]]
                R = [[sum(rot[r][k] * tilt[k][q] for k in range(3)) for q in range(3)] for r in range(3)]
                out.append({"name": f"ArcadeRoof{i}{s}", "cls": "Part",
                            "pos": (mx + n[0] * s * STREET_W * 0.33, 16, mz + n[1] * s * STREET_W * 0.33),
                            "size": (L, 0.3, STREET_W * 0.38), "rot": R, "color": rgb(205, 228, 242),
                            "material": "Glass", "transparency": 0.4, "collide": False})
            out.append(box(f"ArcadeTop{i}", mx, 17.4, mz, L, 0.3, STREET_W * 0.36, yaw, rgb(205, 228, 242), "Glass",
                           transparency=0.4, collide=False))
            k = max(int(L // 12), 1)
            for r in range(k + 1):
                px, pz = at(L * r / k, 0)
                out.append(box(f"Rib{i}_{r}", px, 16.2, pz, 0.5, 0.5, STREET_W + 2, yaw, METAL, "Metal", collide=False))
                for s in (-1, 1):
                    qx, qz = at(L * r / k, s * (STREET_W / 2 + 1))
                    out.append(box(f"RibPost{i}_{r}{s}", qx, 0, qz, 0.5, 16.2, 0.5, yaw, METAL, "Metal"))
            # 칸마다 양쪽: 상점 간판 + 차양 + 좌판
            for r in range(int(L // 12)):
                u = (r + 0.5) * 12
                for s in (-1, 1):
                    t += 1
                    face = face_toward(yaw, (-n[0] * s, -n[1] * s))
                    px, pz = at(u, s * (STREET_W / 2 + 0.6))
                    out.append(labeled(box(f"ShopSign{t}", px, 10, pz, 10, 3, 0.4, yaw,
                                           SHOP_COLORS[t % len(SHOP_COLORS)], "SmoothPlastic"),
                                       SHOP_NAMES[t % len(SHOP_NAMES)], face, ppu=10))
                    px, pz = at(u, s * (STREET_W / 2 - 1.2))
                    out.append(box(f"Awning{t}", px, 8, pz, 10, 0.3, 3, yaw, [rgb(220, 60, 60), rgb(240, 240, 240),
                                                                               rgb(40, 110, 200)][t % 3], "Fabric",
                                   collide=False))
                    px, pz = at(u, s * (STREET_W / 2 - 2.5))
                    out.append(box(f"Stall{t}", px, 0, pz, 8.5, 3, 3, yaw, rgb(160, 115, 70), "Wood"))
                    for g in range(3):
                        gx, gz = at(u - 3 + g * 3, s * (STREET_W / 2 - 2.5))
                        out.append(_ball(f"Goods{t}_{g}", gx, 3.8, gz, 1.6, goods[(t + g) % len(goods)]))
        else:
            # 지붕 없는 장터: 한쪽 나무 데크 + 화분/벤치, 가운데 무지개 파라솔, 반대쪽 흰 천막
            dx, dz = at(L / 2, 6)
            out.append(box(f"Deck{i}", dx, 0, dz, L, 0.4, 4.5, yaw, rgb(170, 125, 80), "WoodPlanks"))
            ex, ez = at(L / 2, -STREET_W / 2 + 0.4)
            out.append(box(f"CurbLine{i}", ex, 0.2, ez, L, 0.06, 0.6, yaw, rgb(250, 200, 30), "SmoothPlastic",
                           collide=False))
            for r in range(int(L // 16)):
                u = 8 + r * 16
                px, pz = at(u, 6)
                out.append(_disc(f"Barrel{i}_{r}", px, 2.0, pz, 3.6, 4.2, rgb(140, 95, 55), "Wood", collide=True))
                out.append(_ball(f"BarrelTree{i}_{r}", px, 6.2, pz, 4.6, rgb(70, 140, 60), "Grass"))
                bx, bz = at(u + 6, 6)
                out.append(box(f"StoneBench{i}_{r}", bx, 0.4, bz, 5, 1.4, 1.8, yaw, rgb(150, 152, 150), "Slate"))
            rainbow = [rgb(230, 60, 60), rgb(250, 200, 40), rgb(60, 170, 90), rgb(50, 120, 220)]
            for r in range(int(L // 9)):
                u = 4.5 + r * 9
                v = 1.5 if r % 2 else -1.5
                t += 1
                px, pz = at(u, v)
                out.append(box(f"ParasolPole{t}", px, 0, pz, 0.3, 8, 0.3, yaw, METAL, "Metal", collide=False))
                for c in range(3):
                    out.append(_disc(f"Parasol{t}_{c}", px, 8 + c * 0.35, pz, 0.35, 8 - c * 2.4,
                                     rainbow[(t + c) % 4]))
                gx, gz = at(u, v)
                out.append(box(f"Mat{t}", gx, 0, gz, 4.5, 0.15, 3.5, yaw, rgb(60, 110, 200), "Fabric", collide=False))
                for g in range(3):
                    hx, hz = at(u - 1.4 + g * 1.4, v)
                    out.append(_ball(f"Veg{t}_{g}", hx, 0.8, hz, 1.2, goods[(t + g) % len(goods)]))
            for r in range(int(L // 14)):
                u = 7 + r * 14
                t += 1
                px, pz = at(u, -5)
                out.append(box(f"TentRoof{t}", px, 8, pz, 7, 0.4, 5.5, yaw, rgb(245, 245, 245), "Fabric", collide=False))
                out.append(box(f"TentValance{t}", px, 7.4, pz, 7.2, 0.6, 5.7, yaw, rgb(40, 110, 210), "Fabric",
                               collide=False))
                for cu in (-1, 1):
                    for cv in (-1, 1):
                        qx, qz = at(u + cu * 3.3, -5 + cv * 2.5)
                        out.append(box(f"TentPost{t}{cu}{cv}", qx, 0, qz, 0.25, 8, 0.25, yaw, rgb(230, 230, 230),
                                       "Metal", collide=False))
                bx, bz = at(u, -5)
                out.append(box(f"Crates{t}", bx, 0, bz, 4, 1.6, 2, yaw, rgb(200, 150, 90), "Wood"))
    # 아케이드 양 끝 '시장1길' 문
    p0, p1 = street_pts[0], street_pts[1]
    out += market_gate(0, p0, _unit(_sub(p1, p0)), STREET_W)
    q0, q1 = street_pts[covered], street_pts[covered - 1]
    out += market_gate(1, q0, _unit(_sub(q1, q0)), STREET_W)
    return out
