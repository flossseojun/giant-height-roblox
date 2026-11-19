"""도로 → 파트 (선분 상자, 꺾이는 점 이음, 큰길 중앙선·인도)."""
import math

from osm.project import SCALE

ASPHALT = (70 / 255, 70 / 255, 75 / 255)
SERVICE = (92 / 255, 92 / 255, 97 / 255)
WALK = (196 / 255, 190 / 255, 178 / 255)
YELLOW = (250 / 255, 200 / 255, 40 / 255)
MAJOR = ("primary", "secondary", "tertiary")
FOOT = ("footway", "path", "cycleway", "steps", "pedestrian")
CYL_UP = [[0, -1, 0], [1, 0, 0], [0, 0, 1]]


def road_width_m(tags) -> float:
    lanes = tags.get("lanes")
    if lanes:
        try:
            return float(lanes) * 3.5
        except ValueError:
            pass
    hw = tags.get("highway", "")
    if hw in ("secondary", "tertiary", "primary"):
        return 7
    if hw.endswith("_link"):
        return 6
    if hw in ("residential", "unclassified", "living_street"):
        return 5
    if hw == "service":
        return 3.5
    return 2.5


def _seg_box(name, a, b, width, y, thick, color, material):
    dx, dz = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dz)
    yaw = math.atan2(dz, dx)
    c, s = math.cos(-yaw), math.sin(-yaw)
    return {"name": name, "cls": "Part", "pos": ((a[0] + b[0]) / 2, y + thick / 2, (a[1] + b[1]) / 2),
            "size": (L, thick, width), "rot": [[c, 0, s], [0, 1, 0], [-s, 0, c]], "color": color,
            "material": material}


def _offset(a, b, d):
    dx, dz = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dz) or 1
    nx, nz = -dz / L * d, dx / L * d
    return (a[0] + nx, a[1] + nz), (b[0] + nx, b[1] + nz)


def simplify(pts, tol):
    """Douglas-Peucker: 모양을 tol 스터드 이내로 유지하며 점 줄이기"""
    if len(pts) < 3:
        return list(pts)
    a, b = pts[0], pts[-1]
    dx, dz = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dz)
    best, idx = -1.0, 0
    for i in range(1, len(pts) - 1):
        px, pz = pts[i]
        dist = abs(dz * (px - a[0]) - dx * (pz - a[1])) / L if L > 1e-9 else math.dist(pts[i], a)
        if dist > best:
            best, idx = dist, i
    if best <= tol:
        return [a, b]
    return simplify(pts[:idx + 1], tol)[:-1] + simplify(pts[idx:], tol)


SKIP = ("cycleway", "path", "track", "steps", "bridleway", "corridor")


def road_parts(way) -> list:
    hw = way.tags.get("highway", "")
    wm = road_width_m(way.tags)
    width = wm * SCALE
    foot = hw in FOOT
    major = hw in MAJOR or hw.endswith("_link") and hw[:-5] in MAJOR
    y = 0.16 if foot else (0.22 if major else (0.18 if hw != "service" else 0.17))
    color = WALK if foot else (SERVICE if hw == "service" else ASPHALT)
    mat = "Slate" if foot else "Asphalt"
    parts = []
    if hw in SKIP:
        return parts
    pts = simplify(way.pts, 3.0 if hw == "service" else 1.5)
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        if math.dist(a, b) < 0.5:
            continue
        parts.append(_seg_box(f"Road{i}", a, b, width, 0, y, color, mat))
        if major:
            if wm >= 7:
                parts.append(_seg_box(f"CenterLine{i}", a, b, 0.5, 0, y + 0.03, YELLOW, "SmoothPlastic"))
            for side in (-1, 1):
                sa, sb = _offset(a, b, side * (width / 2 + 1.6))
                parts.append(_seg_box(f"Sidewalk{i}{side}", sa, sb, 3.2, 0, 0.3, WALK, "Slate"))
    if width >= 5 * SCALE:
        for i in range(1, len(pts) - 1):
            a, b, c = pts[i - 1], pts[i], pts[i + 1]
            turn = abs(math.atan2(c[1] - b[1], c[0] - b[0]) - math.atan2(b[1] - a[1], b[0] - a[0]))
            turn = min(turn, 2 * math.pi - turn)
            if turn < math.radians(12):
                continue  # 거의 일직선이면 이음 필요 없음
            x, z = b
            parts.append({"name": f"Joint{i}", "cls": "Part", "shape": "Cylinder", "pos": (x, y / 2, z),
                          "size": (y, width, width), "rot": CYL_UP, "color": color, "material": mat})
    return parts


def road_segments(ways) -> list:
    out = []
    for w in ways:
        if w.tags.get("highway") in (None, "steps"):
            continue
        width = road_width_m(w.tags) * SCALE
        for i in range(len(w.pts) - 1):
            (x0, z0), (x1, z1) = w.pts[i], w.pts[i + 1]
            out.append((x0, z0, x1, z1, width))
    return out
