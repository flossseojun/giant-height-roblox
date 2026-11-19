"""고가 철로·승강장 → 파트, 하천 → 스튜디오 지형 Luau."""
import math

from osm.geom import min_rect
from osm.project import SCALE
from osm.roads import simplify, _seg_box

DECK_Y = 18
DECK_T = 2.5
CONC = (172 / 255, 172 / 255, 168 / 255)
PILLAR = (150 / 255, 150 / 255, 146 / 255)
RAIL = (95 / 255, 95 / 255, 100 / 255)
PLAT = (205 / 255, 205 / 255, 200 / 255)
ROOF = (232 / 255, 236 / 255, 240 / 255)
YELLOW = (250 / 255, 210 / 255, 40 / 255)


def rail_parts(ways) -> list:
    parts = []
    for w in ways:
        pts = simplify(w.pts, 1.0)
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            L = math.dist(a, b)
            if L < 0.5:
                continue
            tag = f"{w.id}_{i}"
            parts.append(_seg_box(f"Deck{tag}", a, b, 7, DECK_Y - DECK_T, DECK_T, CONC, "Concrete"))
            for side, nm in ((-1.15, "L"), (1.15, "R")):
                dx, dz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
                o = (-dz * side, dx * side)
                parts.append(_seg_box(f"Rail{nm}{tag}", (a[0] + o[0], a[1] + o[1]), (b[0] + o[0], b[1] + o[1]), 0.35,
                                      DECK_Y, 0.45, RAIL, "Metal"))
            n = int(L // 40)
            for k in range(n + 1):
                t = (k + 0.5) / (n + 1)
                x, z = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                parts.append({"name": f"Pillar{tag}_{k}", "cls": "Part", "pos": (x, (DECK_Y - DECK_T) / 2, z),
                              "size": (3, DECK_Y - DECK_T, 3), "rot": [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
                              "color": PILLAR, "material": "Concrete"})
    return parts


def _box_rot(cx, y0, cz, w, h, d, yaw, name, color, material):
    c, s = math.cos(-yaw), math.sin(-yaw)
    return {"name": name, "cls": "Part", "pos": (cx, y0 + h / 2, cz), "size": (w, h, d),
            "rot": [[c, 0, s], [0, 1, 0], [-s, 0, c]], "color": color, "material": material}


def platform_parts(ways) -> list:
    """승강장 윤곽 → 승강장 판(윗면 DECK_Y+2), 노란 안전선, 지붕(판 위 9스터드)과 기둥"""
    parts = []
    for i, w in enumerate(ways):
        pts = w.pts[:-1] if w.closed else w.pts
        cx, cz, L, W, yaw = min_rect(pts)
        if W > L:
            L, W, yaw = W, L, yaw + math.pi / 2
        parts.append(_box_rot(cx, DECK_Y, cz, L, 2, W, yaw, f"Platform{i}", PLAT, "Concrete"))
        c, s = math.cos(yaw), math.sin(yaw)
        for side in (-1, 1):
            ox, oz = -s * side * (W / 2 - 0.6), c * side * (W / 2 - 0.6)
            parts.append(_box_rot(cx + ox, DECK_Y + 2, cz + oz, L, 0.05, 0.6, yaw, f"SafetyLine{i}{side}", YELLOW,
                                  "SmoothPlastic"))
        parts.append(_box_rot(cx, DECK_Y + 11, cz, L, 0.6, W + 1, yaw, f"CanopyRoof{i}", ROOF, "Metal"))
        n = max(1, int(L // 16))
        for k in range(n + 1):
            t = -L / 2 + L * k / n
            parts.append(_box_rot(cx + c * t, DECK_Y + 2, cz + s * t, 0.6, 9, 0.6, yaw, f"RoofPost{i}_{k}", ROOF,
                                  "Metal"))
    return parts


def _width(w) -> float:
    try:
        return float(w.tags.get("width")) * SCALE
    except (TypeError, ValueError):
        return (120 if w.tags.get("waterway") == "river" else 12) * SCALE


def water_cuts(ways) -> list:
    out = []
    for w in ways:
        pts = simplify(w.pts, 2.0)
        wd = _width(w)
        for i in range(len(pts) - 1):
            out.append((pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], wd))
    return out


def water_luau(ways) -> str:
    """양근천·남한강을 지형 물로: 모래 바닥 + 물 + 꺾이는 점 원기둥"""
    lines = ["-- 자동 생성: tools/osm/rail_water.py water_luau()", "local T = workspace.Terrain",
             "local W, S = Enum.Material.Water, Enum.Material.Sand"]
    n = 0
    for x0, z0, x1, z1, wd in water_cuts(ways):
        L = math.hypot(x1 - x0, z1 - z0)
        if L < 0.5:
            continue
        yaw = math.atan2(z1 - z0, x1 - x0)
        mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
        cf = f"CFrame.new({mx:.1f}, %s, {mz:.1f}) * CFrame.Angles(0, {-yaw:.4f}, 0)"
        lines.append(f"T:FillBlock({cf % '-10'}, Vector3.new({L + 2:.1f}, 4, {wd + 6:.1f}), S)")
        lines.append(f"T:FillBlock({cf % '-4.25'}, Vector3.new({L + 2:.1f}, 7.5, {wd:.1f}), W)")
        lines.append(f"T:FillCylinder(CFrame.new({x1:.1f}, -4.25, {z1:.1f}), 7.5, {wd / 2:.1f}, W)")
        n += 1
        if n % 10 == 0:
            lines.append("task.wait()")
    lines.append("task.wait()")
    lines.append('return "water ok"')
    return "\n".join(lines)
