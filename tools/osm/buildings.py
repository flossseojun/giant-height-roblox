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


def floors(tags: dict, way_id: int) -> int:
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


def building_parts(way) -> list:
    pts = way.pts[:-1] if way.closed and len(way.pts) > 3 else way.pts
    n = floors(way.tags, way.id)
    h = n * FLOOR
    rnd = random.Random(way.id)
    color = PALETTE[rnd.randrange(len(PALETTE))]
    cx, cz, w, d, yaw = min_rect(pts)
    parts = []
    tris = [] if rectangularity(pts) >= 0.78 else triangulate(pts)
    if tris and len(tris) <= MAX_TRIS:
        for i, t in enumerate(tris):
            for j, wd in enumerate(wedges(t, 0, h)):
                wd.update(name=f"Body{i}_{j}", color=color, material="Concrete")
                parts.append(wd)
        return parts
    w, d = max(w, 1), max(d, 1)
    parts.append(box("Body", cx, 0, cz, w, h, d, yaw, color))
    parts.append(box("Roof", cx, h, cz, w + 0.4, 0.6, d + 0.4, yaw, ROOF, "Slate"))
    # 창문 띠: 긴 두 면에, 층 수가 많으면 최대 8줄
    long_is_w = w >= d
    rows = min(n - 1, 6 if n >= 10 else 3) if n > 1 else 0
    if rows and max(w, d) >= 12:
        step = (n - 1) / rows
        c, s = math.cos(yaw), math.sin(yaw)
        for k in range(rows):
            fy = round(1 + k * step) * FLOOR + FLOOR * 0.35
            for side in (-1, 1):
                if long_is_w:
                    ox, oz = -s * side * (d / 2 + 0.15), c * side * (d / 2 + 0.15)
                    parts.append(box(f"Win{k}{side}", cx + ox, fy, cz + oz, w - 2, FLOOR * 0.4, 0.3, yaw, WINDOW, "Glass"))
                else:
                    ox, oz = c * side * (w / 2 + 0.15), s * side * (w / 2 + 0.15)
                    parts.append(box(f"Win{k}{side}", cx + ox, fy, cz + oz, 0.3, FLOOR * 0.4, d - 2, yaw, WINDOW, "Glass"))
    return parts
