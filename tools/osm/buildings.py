"""건물 윤곽 → 파트 (몸체 + 창문 띠 + 지붕)."""
import math
import random

from osm.geom import min_rect, rectangularity, triangulate, wedges
from osm.project import FLOOR


def rgb(r, g, b):
    return (r / 255, g / 255, b / 255)


PALETTE = [rgb(236, 230, 218), rgb(218, 210, 196), rgb(196, 128, 104), rgb(242, 242, 238), rgb(205, 214, 222),
           rgb(226, 206, 170), rgb(184, 190, 196)]
WINDOW = rgb(78, 104, 130)
ROOF = rgb(120, 118, 116)
MAX_TRIS = 10


def floors(tags: dict, way_id: int, downtown: bool = False) -> int:
    lv = tags.get("building:levels")
    if lv:
        try:
            return max(1, int(float(lv)))
        except ValueError:
            pass
    b = tags.get("building", "yes")
    if b == "apartments":
        return 15
    if b in ("commercial", "retail", "office"):
        return 4
    if b in ("house", "detached", "residential", "semidetached_house"):
        return 2
    if downtown and b == "yes":
        return random.Random(way_id).choice((3, 3, 4, 4, 5))
    return random.Random(way_id).choice((2, 3))


def _rot_y(yaw):
    """로컬 X축이 (cos yaw, 0, sin yaw)를 향하게"""
    c, s = math.cos(-yaw), math.sin(-yaw)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def box(name, cx, y0, cz, w, h, d, yaw, color, material="Concrete", **extra):
    p = {"name": name, "cls": "Part", "pos": (cx, y0 + h / 2, cz), "size": (w, h, d), "rot": _rot_y(yaw),
         "color": color, "material": material}
    p.update(extra)
    return p


# ------------------------------------------------------------------ 스타일별 외관
HOUSE_WALL = [rgb(160, 86, 66), rgb(128, 72, 56), rgb(222, 205, 170), rgb(236, 228, 212), rgb(238, 238, 234),
              rgb(200, 200, 196)]
HOUSE_ROOF = [rgb(70, 72, 78), rgb(60, 110, 112), rgb(168, 82, 58), rgb(62, 96, 72)]
SHOP_WALL = [rgb(222, 205, 170), rgb(236, 228, 212), rgb(205, 205, 200), rgb(242, 242, 238), rgb(205, 142, 112),
             rgb(150, 106, 82), rgb(232, 150, 60)]
APT_WALL = [rgb(242, 240, 234), rgb(236, 230, 216), rgb(228, 230, 232)]
ACCENT = [rgb(40, 140, 150), rgb(40, 70, 140), rgb(230, 130, 40), rgb(70, 140, 80), rgb(170, 60, 60)]
SIGN_BG = [rgb(200, 40, 40), rgb(30, 80, 170), rgb(20, 130, 80), rgb(250, 200, 30), rgb(120, 50, 140),
           rgb(240, 240, 240), rgb(30, 30, 34), rgb(240, 120, 30)]
SHOP_WORDS = ["약국", "치과", "내과", "부동산", "PC방", "노래방", "미용실", "분식", "치킨", "카페", "편의점", "안경",
              "휴대폰", "정육점", "한의원", "태권도", "피아노", "수학학원", "영어학원", "세탁소", "김밥", "국밥", "제과점",
              "꽃집", "철물점", "보험", "당구장", "헬스", "식당", "횟집", "반찬", "떡집", "중국집", "소아과", "독서실"]
GLASS_DARK = rgb(52, 66, 82)
FRAME = rgb(225, 225, 222)
TANK = [rgb(70, 130, 200), rgb(200, 205, 210), rgb(240, 240, 240)]
FACE_NAME = {"+X": "Right", "-X": "Left", "+Z": "Back", "-Z": "Front"}


class Frame:
    """직사각형 건물의 로컬 좌표계: X = (cos yaw, sin yaw), Z = (-sin yaw, cos yaw)"""

    def __init__(self, cx, cz, w, d, yaw):
        self.cx, self.cz, self.w, self.d, self.yaw = cx, cz, w, d, yaw
        self.X = (math.cos(yaw), math.sin(yaw))
        self.Z = (-math.sin(yaw), math.cos(yaw))

    def at(self, u, v):
        return self.cx + self.X[0] * u + self.Z[0] * v, self.cz + self.X[1] * u + self.Z[1] * v

    def face_geo(self, face):
        """→ (법선 부호·축, 면까지 거리, 면 길이)"""
        return {"+X": (self.w / 2, self.d), "-X": (self.w / 2, self.d), "+Z": (self.d / 2, self.w),
                "-Z": (self.d / 2, self.w)}[face]

    def on_face(self, name, face, along, y0, height, width, thick, color, material="SmoothPlastic", out=0.0, **extra):
        hd, _ = self.face_geo(face)
        sgn = 1 if face[0] == "+" else -1
        off = sgn * (hd + thick / 2 + out)
        if face[1] == "X":
            x, z = self.at(off, along)
            return box(name, x, y0, z, thick, height, width, self.yaw, color, material, **extra)
        x, z = self.at(along, off)
        return box(name, x, y0, z, width, height, thick, self.yaw, color, material, **extra)

    def facing(self, px, pz):
        """점 (px,pz)를 가장 바로 보는 면"""
        vx, vz = px - self.cx, pz - self.cz
        u = vx * self.X[0] + vz * self.X[1]
        v = vx * self.Z[0] + vz * self.Z[1]
        if abs(u) / max(self.w, 1) >= abs(v) / max(self.d, 1):
            return "+X" if u > 0 else "-X"
        return "+Z" if v > 0 else "-Z"


def _labeled(spec, text, face, fg=(1, 1, 1), ppu=10):
    spec["label"] = (text, FACE_NAME[face], fg, ppu)
    return spec


def _through(F, name, y0, height, long_faces, frac, color, material="Glass", u_off=0.0, seg_w=None):
    """몸체를 관통하는 얇은 판 하나로 마주 보는 두 면에 창(띠)을 동시에 만든다."""
    if long_faces == "Z":  # ±Z 면에 보이게: X 방향으로 길고 Z로 몸체보다 0.3 두꺼움
        wlen = seg_w if seg_w else F.w * frac
        x, z = F.at(u_off, 0)
        return box(name, x, y0, z, wlen, height, F.d + 0.3, F.yaw, color, material)
    wlen = seg_w if seg_w else F.d * frac
    x, z = F.at(0, u_off)
    return box(name, x, y0, z, F.w + 0.3, height, wlen, F.yaw, color, material)


def _rooftop(F, h, rnd, wall, parts, tank=True, hut=True):
    if hut and F.w > 10 and F.d > 8:
        x, z = F.at(F.w * 0.22, F.d * 0.1)
        parts.append(box("StairHut", x, h, z, 4.5, 5.5, 4.5, F.yaw, wall))
    if tank and F.w > 8:
        x, z = F.at(-F.w * 0.2, -F.d * 0.12)
        parts.append({"name": "WaterTank", "cls": "Part", "shape": "Cylinder", "pos": (x, h + 1.7, z),
                      "size": (3.4, 3.4, 3.4), "rot": [[0, -1, 0], [1, 0, 0], [0, 0, 1]],
                      "color": TANK[rnd.randrange(len(TANK))], "material": "SmoothPlastic"})


def _sign_style(rnd):
    bg = SIGN_BG[rnd.randrange(len(SIGN_BG))]
    fg = rgb(30, 30, 30) if bg in (SIGN_BG[3], SIGN_BG[5]) else (1, 1, 1)
    return bg, fg, SHOP_WORDS[rnd.randrange(len(SHOP_WORDS))]


def _shop(F, n, rnd, street, parts):
    h = n * FLOOR
    wall = SHOP_WALL[rnd.randrange(len(SHOP_WALL))]
    parts.append(box("Body", F.cx, 0, F.cz, F.w, h, F.d, F.yaw, wall))
    parts.append(box("Roof", F.cx, h, F.cz, F.w + 0.6, 0.8, F.d + 0.6, F.yaw, rgb(196, 196, 192), "Concrete"))
    if wall == SHOP_WALL[-1]:  # 주황 건물 + 파란 띠 (시장 사진)
        parts.append(box("AccentBand", F.cx, h - 2.2, F.cz, F.w + 0.4, 1.2, F.d + 0.4, F.yaw, rgb(40, 90, 190),
                         "SmoothPlastic"))
    sf = street
    hd, fl = F.face_geo(sf)
    # 1층: 통유리 가게 + 간판 띠 + 차양
    parts.append(F.on_face("Storefront", sf, 0, 0.2, FLOOR * 0.62, fl - 2, 0.3, GLASS_DARK, "Glass"))
    # 1층을 가게 여러 칸으로 나눠 칸마다 간판 (글씨가 간판 폭에 맞게 크게 보이도록)
    units = max(1, round(fl / 13))
    uw = fl / units
    for ui in range(units):
        bg, fg, word = _sign_style(rnd)
        along = -fl / 2 + uw * (ui + 0.5)
        parts.append(_labeled(F.on_face("SignBand" if ui == 0 else f"SignBand{ui}", sf, along, FLOOR * 0.63,
                                        FLOOR * 0.34, uw - 0.6, 0.4, bg, out=0.05), word, sf, fg, ppu=8))
        if units > 1 and ui:
            parts.append(F.on_face(f"ShopDivider{ui}", sf, -fl / 2 + uw * ui, 0, FLOOR * 0.97, 0.6, 0.5, wall,
                                   out=0.05))
    # 위층: 층마다 관통 창 2~3칸 + 간판
    segs = 3 if max(F.w, F.d) > 22 else 2
    long_faces = "Z" if sf[1] == "Z" else "X"
    span = (F.w if long_faces == "Z" else F.d)
    seg_w = span / segs * 0.62
    for f in range(1, n):
        y = f * FLOOR + FLOOR * 0.3
        for sgi in range(segs):
            uo = (sgi - (segs - 1) / 2) * span / segs
            parts.append(_through(F, f"Win{f}_{sgi}", y, FLOOR * 0.45, long_faces, 0, GLASS_DARK, u_off=uo,
                                  seg_w=seg_w))
        if f <= 2 and rnd.random() < 0.8:
            bg, fg, word = _sign_style(rnd)
            sw = min(fl * 0.6, 11)
            along = (fl / 2 - sw / 2 - 1) * (1 if f % 2 else -1)
            parts.append(_labeled(F.on_face(f"FloorSign{f}", sf, along, f * FLOOR + FLOOR * 0.74, FLOOR * 0.3,
                                            sw, 0.4, bg, out=0.25), word, sf, fg, ppu=9))
    if n >= 3 and rnd.random() < 0.5:  # 모서리 세로 간판
        bg, fg, word = _sign_style(rnd)
        parts.append(_labeled(F.on_face("VSign", sf, fl / 2 - 1.5, FLOOR * 1.1, FLOOR * (n - 1.4), 2.2, 0.5, bg,
                                        out=0.6), "\n".join(word), sf, fg, ppu=9))
    _rooftop(F, h + 0.8, rnd, wall, parts)


def _house(F, n, rnd, street, parts):
    h = n * FLOOR
    wall = HOUSE_WALL[rnd.randrange(len(HOUSE_WALL))]
    parts.append(box("Body", F.cx, 0, F.cz, F.w, h, F.d, F.yaw, wall))
    long_faces = "Z" if F.w >= F.d else "X"
    span = max(F.w, F.d)
    for f in range(n):
        y = f * FLOOR + FLOOR * 0.32
        for sgi, uo in enumerate((-span * 0.22, span * 0.22)):
            parts.append(_through(F, f"Win{f}_{sgi}", y, FLOOR * 0.38, long_faces, 0, GLASS_DARK, u_off=uo,
                                  seg_w=min(4.5, span * 0.2)))
    if street:
        hd, fl = F.face_geo(street)
        parts.append(F.on_face("Door", street, 0, 0, 5.2, 2.8, 0.3, rgb(110, 80, 60), "Wood"))
    if rnd.random() < 0.6 and min(F.w, F.d) <= 26:  # 박공지붕
        roof = HOUSE_ROOF[rnd.randrange(len(HOUSE_ROOF))]
        rh = min(F.w, F.d) * 0.28
        if F.w >= F.d:
            L, half = F.w + 1.2, F.d / 2 + 0.6
            for nm, v, yaw in (("RoofA", half / 2, F.yaw + math.pi), ("RoofB", -half / 2, F.yaw)):
                x, z = F.at(0, v)
                q = box(nm, x, h, z, L, rh, half, yaw, roof, "Slate")
                q["cls"] = "WedgePart"
                parts.append(q)
        else:
            L, half = F.d + 1.2, F.w / 2 + 0.6
            for nm, u, yaw in (("RoofA", half / 2, F.yaw + math.pi / 2), ("RoofB", -half / 2, F.yaw - math.pi / 2)):
                x, z = F.at(u, 0)
                q = box(nm, x, h, z, L, rh, half, yaw, roof, "Slate")
                q["cls"] = "WedgePart"
                parts.append(q)
    else:
        parts.append(box("Roof", F.cx, h, F.cz, F.w + 0.4, 0.7, F.d + 0.4, F.yaw, rgb(150, 150, 148), "Concrete"))
        _rooftop(F, h + 0.7, rnd, wall, parts, hut=False)


def _apartment(F, n, rnd, way_id, parts):
    h = n * FLOOR
    wall = APT_WALL[rnd.randrange(len(APT_WALL))]
    acc = ACCENT[rnd.randrange(len(ACCENT))]
    parts.append(box("Body", F.cx, 0, F.cz, F.w, h, F.d, F.yaw, wall))
    long_faces = "Z" if F.w >= F.d else "X"
    step = max(1, math.ceil(n / 26))
    for f in range(1, n, step):
        parts.append(_through(F, f"Balcony{f}", f * FLOOR + 1.2, FLOOR * 0.5, long_faces, 0.92, rgb(120, 150, 175)))
    parts.append(box("Crown", F.cx, h, F.cz, F.w + 0.6, 3, F.d + 0.6, F.yaw, acc, "SmoothPlastic"))
    num = f"{101 + way_id % 12}동"
    ends = ("+X", "-X") if long_faces == "Z" else ("+Z", "-Z")
    for e in ends:
        hd, fl = F.face_geo(e)
        parts.append(_labeled(F.on_face(f"DongNo{e}", e, 0, h - 14, 9, min(fl * 0.7, 14), 0.3, wall, out=0.05), num, e,
                              acc, ppu=5))
        parts.append(F.on_face(f"EndStripe{e}", e, -fl * 0.35, 0, h - 16, 2.2, 0.3, acc, out=0.05))


def _civic(F, n, rnd, tags, parts):
    h = n * FLOOR
    b = tags.get("building")
    wall = rgb(238, 230, 208) if b == "school" else rgb(232, 232, 228)
    parts.append(box("Body", F.cx, 0, F.cz, F.w, h, F.d, F.yaw, wall))
    parts.append(box("Roof", F.cx, h, F.cz, F.w + 0.6, 0.8, F.d + 0.6, F.yaw, rgb(150, 150, 150), "Concrete"))
    for f in range(n):
        y = f * FLOOR + FLOOR * 0.3
        parts.append(_through(F, f"WinZ{f}", y, FLOOR * 0.42, "Z", 0.88, GLASS_DARK))
        parts.append(_through(F, f"WinX{f}", y, FLOOR * 0.42, "X", 0.88, GLASS_DARK))
    if b == "church" or tags.get("amenity") == "place_of_worship":
        x, z = F.at(F.w * 0.3, 0)
        parts.append(box("Steeple", x, h, z, 3.5, 10, 3.5, F.yaw, wall))
        parts.append(box("CrossV", x, h + 10, z, 0.6, 5, 0.6, F.yaw, rgb(220, 40, 40), "Neon"))
        parts.append(box("CrossH", x, h + 12.6, z, 0.6, 0.6, 3, F.yaw, rgb(220, 40, 40), "Neon"))


def _edge_windows(pts, n, rnd, parts):
    """비정형 건물: 긴 변마다 층별 창 띠"""
    area2 = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
                for i in range(len(pts)))
    sgn = 1 if area2 > 0 else -1
    cnt = 0
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 10:
            continue
        dx, dz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        nx, nz = dz * sgn, -dx * sgn  # 바깥쪽 법선
        yaw = math.atan2(dz, dx)
        for f in range(n):
            if cnt >= 16:
                return
            x = (a[0] + b[0]) / 2 + nx * 0.15
            z = (a[1] + b[1]) / 2 + nz * 0.15
            parts.append(box(f"EWin{i}_{f}", x, f * FLOOR + FLOOR * 0.3, z, L - 3, FLOOR * 0.42, 0.3, yaw, GLASS_DARK,
                             "Glass"))
            cnt += 1


def building_parts(way, ctx=None) -> list:
    """ctx: {"street": (x,z) 가장 가까운 도로 위 점, "downtown": 큰길가 여부}"""
    ctx = ctx or {}
    pts = way.pts[:-1] if way.closed and len(way.pts) > 3 else way.pts
    downtown = ctx.get("downtown", False)
    n = floors(way.tags, way.id, downtown)
    h = n * FLOOR
    rnd = random.Random(way.id)
    cx, cz, w, d, yaw = min_rect(pts)
    parts = []
    tris = [] if rectangularity(pts) >= 0.78 else triangulate(pts)
    if tris and len(tris) <= MAX_TRIS:
        color = (SHOP_WALL if downtown else HOUSE_WALL)[rnd.randrange(6)]
        for i, t in enumerate(tris):
            for j, wd in enumerate(wedges(t, 0, h)):
                wd.update(name=f"Body{i}_{j}", color=color, material="Concrete")
                parts.append(wd)
        _edge_windows(pts, n, rnd, parts)
        return parts
    F = Frame(cx, cz, max(w, 1), max(d, 1), yaw)
    street = ctx.get("street")
    sf = F.facing(*street) if street else None
    b = way.tags.get("building", "yes")
    if n >= 10:
        _apartment(F, n, rnd, way.id, parts)
    elif b in ("school", "civic", "public", "church", "hospital", "industrial", "government", "kindergarten"):
        _civic(F, n, rnd, way.tags, parts)
    elif (downtown or b in ("commercial", "retail", "office")) and sf and F.w >= 8 and F.d >= 8:
        _shop(F, n, rnd, sf, parts)
    else:
        _house(F, n, rnd, sf, parts)
    return parts
