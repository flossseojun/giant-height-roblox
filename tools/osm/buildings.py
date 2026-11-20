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


SHOP_TYPES = ["karaoke", "pcbang", "cafe", "chicken", "mart", "pharmacy", "salon", "snack", "academy", "flower"]
# 가게 종류별 간판 띠 색 (글씨 없음)
SHOP_BAND = {"karaoke": rgb(120, 40, 160), "pcbang": rgb(25, 35, 80), "cafe": rgb(120, 80, 50),
             "chicken": rgb(250, 200, 30), "mart": rgb(245, 245, 245), "pharmacy": rgb(240, 245, 240),
             "salon": rgb(245, 245, 245), "snack": rgb(200, 40, 40), "academy": rgb(30, 60, 130),
             "flower": rgb(70, 150, 80)}
UP_ROT = [[0, -1, 0], [1, 0, 0], [0, 0, 1]]
NEON_PINK, NEON_BLUE = rgb(255, 80, 200), rgb(60, 160, 255)


def _prop(F, name, sf, along, y0, out, w, h, d, color, material="SmoothPlastic", shape=None):
    """가게 앞면 기준 장식: along=가로 위치, out=벽에서 떨어진 거리(앞쪽), w/h/d=가로/높이/깊이"""
    q = F.on_face(name, sf, along, y0, h, w, d, color, material, out=out)
    if shape == "Ball":
        q["shape"] = "Ball"
    elif shape == "CylUp":  # 세로 원기둥
        q["shape"] = "Cylinder"
        q["size"] = (h, w, w)
        q["rot"] = UP_ROT
    return q


def _deco(t, F, sf, a, uw, parts, rich, k):
    """가게 한 칸(a: 칸 중심, uw: 칸 폭)에 종류별 생김새"""
    P = lambda *args, **kw: parts.append(_prop(F, f"Deco{k}_" + args[0], sf, *args[1:], **kw))
    top = FLOOR * 0.63 + FLOOR * 0.17  # 간판 띠 가운데 높이
    if t == "karaoke":
        P("NeonTop", a, FLOOR * 0.6, 1.7, uw - 0.6, 0.25, 0.25, NEON_PINK, "Neon")
        P("MicStick", a - uw * 0.25, top - 1.0, 0.5, 0.35, 1.6, 0.35, rgb(40, 40, 45), shape="CylUp")
        P("MicHead", a - uw * 0.25, top + 0.4, 0.5, 0.9, 0.9, 0.9, rgb(200, 200, 210), "Metal", shape="Ball")
        if rich:
            P("MirrorBall", a + uw * 0.15, FLOOR * 0.38, 0.8, 1.3, 1.3, 1.3, rgb(220, 220, 255), "Neon", shape="Ball")
            P("NeonSide", a + uw / 2 - 0.5, 0.2, 1.7, 0.25, FLOOR * 0.4, 0.25, NEON_BLUE, "Neon")
    elif t == "pcbang":
        n_mon = 3 if rich else 1
        for i in range(n_mon):
            off = (i - (n_mon - 1) / 2) * (uw / (n_mon + 0.5))
            P(f"Monitor{i}", a + off, 1.8, 0.9, min(2.2, uw / (n_mon + 1)), 1.4, 0.2, NEON_BLUE, "Neon")
        P("LedStrip", a, FLOOR * 0.62, 0.45, uw - 0.6, 0.2, 0.2, NEON_BLUE, "Neon")
        if rich:
            P("Chairs", a, 0.2, 0.4, uw * 0.6, 1.2, 0.5, rgb(30, 30, 35))
    elif t == "cafe":
        P("CupBody", a - uw * 0.3, top - 0.6, 0.5, 1.1, 1.3, 1.1, rgb(245, 245, 240), shape="CylUp")
        P("CupHandle", a - uw * 0.3 + 0.75, top - 0.3, 0.5, 0.35, 0.6, 0.35, rgb(245, 245, 240))
        P("TableTop", a + uw * 0.15, 2.0, 3.2, 2.2, 0.2, 2.2, rgb(150, 100, 60), "Wood", shape="CylUp")
        if rich:
            P("TableLeg", a + uw * 0.15, 0, 3.2, 0.25, 2.0, 0.25, rgb(60, 60, 60), shape="CylUp")
            P("Parasol", a + uw * 0.15, 4.6, 3.2, 4.5, 0.3, 4.5, rgb(240, 240, 235), "Fabric", shape="CylUp")
    elif t == "chicken":
        P("Awning", a, FLOOR * 0.58, 0.9, uw - 0.4, 0.3, 1.8, rgb(220, 50, 40), "Fabric")
        P("Drumstick", a + uw * 0.28, top - 0.1, 0.6, 1.3, 1.1, 1.0, rgb(190, 110, 40), shape="Ball")
        P("Bone", a + uw * 0.28 + 0.9, top - 0.1, 0.6, 0.9, 0.3, 0.3, rgb(245, 240, 230))
        if rich:
            P("Table", a - uw * 0.15, 0.2, 1.0, 2.0, 1.4, 1.0, rgb(150, 100, 60), "Wood")
    elif t == "mart":
        P("StripeG", a, FLOOR * 0.63 + 0.25, 0.5, uw - 0.6, 0.35, 0.1, rgb(40, 160, 80))
        P("StripeB", a, FLOOR * 0.63 + 0.75, 0.5, uw - 0.6, 0.35, 0.1, rgb(40, 90, 200))
        P("Shelf", a, 0.2, 0.7, uw * 0.7, 2.6, 0.6, rgb(230, 230, 230))
        if rich:
            P("Goods", a, 1.4, 1.05, uw * 0.6, 0.6, 0.15, rgb(250, 160, 60))
    elif t == "pharmacy":
        P("CrossV", a + uw * 0.3, top - 0.9, 0.5, 0.6, 1.8, 0.3, rgb(40, 220, 90), "Neon")
        P("CrossH", a + uw * 0.3, top - 0.3, 0.5, 1.8, 0.6, 0.3, rgb(40, 220, 90), "Neon")
        if rich:
            P("Shelf", a - uw * 0.1, 0.2, 0.7, uw * 0.5, 2.4, 0.5, rgb(235, 240, 235))
    elif t == "salon":
        for i, c in enumerate((rgb(220, 40, 40), rgb(245, 245, 245), rgb(40, 80, 200))):
            P(f"Pole{i}", a + uw / 2 - 0.7, 0.8 + i * 1.0, 0.6, 0.7, 1.0, 0.7, c, "Neon" if i != 1 else "SmoothPlastic",
              shape="CylUp")
        if rich:
            P("Mirror", a - uw * 0.1, 1.4, 0.6, uw * 0.4, 1.8, 0.1, rgb(200, 220, 235), "Glass")
    elif t == "snack":
        P("Lantern", a - uw * 0.3, FLOOR * 0.55, 1.0, 0.9, 1.1, 0.9, rgb(230, 40, 40), "Neon", shape="Ball")
        P("Pot", a + uw * 0.15, 0.2, 0.9, 1.4, 1.2, 1.4, rgb(70, 70, 75), "Metal", shape="CylUp")
        if rich:
            P("Steam", a + uw * 0.15, 1.6, 0.9, 1.2, 1.2, 1.2, rgb(245, 245, 245), shape="Ball")
    elif t == "academy":
        P("Board", a, 1.6, 0.25, uw * 0.6, 1.6, 0.1, rgb(40, 100, 60))
        if rich:
            P("Desks", a, 0.2, 1.0, uw * 0.6, 1.0, 0.5, rgb(170, 130, 90), "Wood")
    elif t == "flower":
        n_pot = 3 if rich else 2
        for i in range(n_pot):
            off = (i - (n_pot - 1) / 2) * 1.8
            P(f"Pot{i}", a + off, 0, 2.6, 1.0, 0.9, 1.0, rgb(170, 90, 60), shape="CylUp")
            P(f"Flower{i}", a + off, 0.9, 2.6, 1.3, 1.3, 1.3, [rgb(240, 80, 120), rgb(250, 200, 40), rgb(160, 80, 220)][i % 3],
              shape="Ball")


def _shop(F, n, rnd, street, parts, force_type=None):
    h = n * FLOOR
    wall = SHOP_WALL[rnd.randrange(len(SHOP_WALL))]
    parts.append(box("Body", F.cx, 0, F.cz, F.w, h, F.d, F.yaw, wall))
    parts.append(box("Roof", F.cx, h, F.cz, F.w + 0.6, 0.8, F.d + 0.6, F.yaw, rgb(196, 196, 192), "Concrete"))
    if wall == SHOP_WALL[-1]:  # 주황 건물 + 파란 띠 (시장 사진)
        parts.append(box("AccentBand", F.cx, h - 2.2, F.cz, F.w + 0.4, 1.2, F.d + 0.4, F.yaw, rgb(40, 90, 190),
                         "SmoothPlastic"))
    sf = street
    hd, fl = F.face_geo(sf)
    # 1층: 어두운 가게 안쪽 벽 + 칸마다 (앞으로 나온 반투명 유리, 종류 색 간판 띠, 종류별 장식)
    parts.append(F.on_face("Storefront", sf, 0, 0.2, FLOOR * 0.62, fl - 2, 0.3, GLASS_DARK, "Glass"))
    units = max(1, round(fl / 13))
    uw = fl / units
    for ui in range(units):
        t = force_type or SHOP_TYPES[rnd.randrange(len(SHOP_TYPES))]
        a = -fl / 2 + uw * (ui + 0.5)
        parts.append(F.on_face(f"ShopGlass{ui}", sf, a, 0.2, FLOOR * 0.6, uw - 0.8, 0.2, rgb(180, 210, 230), "Glass",
                               out=1.6, transparency=0.45))
        parts.append(F.on_face("SignBand" if ui == 0 else f"SignBand{ui}", sf, a, FLOOR * 0.63, FLOOR * 0.34,
                               uw - 0.6, 0.4, SHOP_BAND[t], out=0.05))
        _deco(t, F, sf, a, uw, parts, rich=uw >= 9, k=ui)
        if units > 1 and ui:
            parts.append(F.on_face(f"ShopDivider{ui}", sf, -fl / 2 + uw * ui, 0, FLOOR * 0.97, 0.6, 1.9, wall,
                                   out=0.05))
    # 위층: 층마다 관통 창 2~3칸, 2·3층엔 가게 종류 빛(노래방 분홍 네온, PC방 파란 빛, 학원 흰 빛)
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
        if f <= 2 and rnd.random() < 0.7:
            glow = [NEON_PINK, NEON_BLUE, rgb(250, 250, 240)][rnd.randrange(3)]
            parts.append(F.on_face(f"FloorGlow{f}", sf, 0, y + FLOOR * 0.45, 0.35, fl * 0.85, 0.25, glow, "Neon",
                                   out=0.1))
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
