"""다각형 도우미: 최소 회전 사각형, 삼각분할, 삼각기둥 → WedgePart 2개."""
import math


def poly_area(pts) -> float:
    a = 0.0
    for i in range(len(pts)):
        x0, z0 = pts[i]
        x1, z1 = pts[(i + 1) % len(pts)]
        a += x0 * z1 - x1 * z0
    return abs(a) / 2


def _signed(pts):
    a = 0.0
    for i in range(len(pts)):
        x0, z0 = pts[i]
        x1, z1 = pts[(i + 1) % len(pts)]
        a += x0 * z1 - x1 * z0
    return a / 2


def _clean(pts, eps=1e-6):
    out = []
    for p in pts:
        if not out or math.dist(p, out[-1]) > eps:
            out.append(p)
    if len(out) > 1 and math.dist(out[0], out[-1]) <= eps:
        out.pop()
    # 일직선 점 제거
    changed = True
    while changed and len(out) >= 3:
        changed = False
        for i in range(len(out)):
            a, b, c = out[i - 1], out[i], out[(i + 1) % len(out)]
            if abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])) <= eps:
                out.pop(i)
                changed = True
                break
    return out


def _hull(pts):
    p = sorted(set(pts))
    if len(p) <= 2:
        return p

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lo, up = [], []
    for q in p:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], q) <= 0:
            lo.pop()
        lo.append(q)
    for q in reversed(p):
        while len(up) >= 2 and cross(up[-2], up[-1], q) <= 0:
            up.pop()
        up.append(q)
    return lo[:-1] + up[:-1]


def min_rect(pts):
    """최소 넓이 회전 사각형 → (cx, cz, w, d, yaw). w는 yaw 방향(로컬 X), d는 그에 수직."""
    h = _hull(pts)
    if len(h) < 3:
        xs, zs = [p[0] for p in pts], [p[1] for p in pts]
        return ((min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2, max(xs) - min(xs), max(zs) - min(zs), 0.0)
    best = None
    for i in range(len(h)):
        x0, z0 = h[i]
        x1, z1 = h[(i + 1) % len(h)]
        a = math.atan2(z1 - z0, x1 - x0)
        c, s = math.cos(a), math.sin(a)
        us = [x * c + z * s for x, z in h]
        vs = [-x * s + z * c for x, z in h]
        area = (max(us) - min(us)) * (max(vs) - min(vs))
        if best is None or area < best[0]:
            um, vm = (max(us) + min(us)) / 2, (max(vs) + min(vs)) / 2
            best = (area, um * c - vm * s, um * s + vm * c, max(us) - min(us), max(vs) - min(vs), a)
    _, cx, cz, w, d, a = best
    return (cx, cz, w, d, a)


def rectangularity(pts) -> float:
    _, _, w, d, _ = min_rect(pts)
    return poly_area(pts) / (w * d) if w * d > 0 else 0.0


def triangulate(pts):
    """귀 자르기. 실패하거나 넓이가 0이면 []"""
    p = _clean(list(pts))
    if len(p) < 3 or poly_area(p) < 1e-9:
        return []
    if _signed(p) < 0:
        p.reverse()
    tris = []
    guard = 0
    while len(p) > 3 and guard < 10000:
        guard += 1
        n = len(p)
        cut = False
        for i in range(n):
            a, b, c = p[i - 1], p[i], p[(i + 1) % n]
            if (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) <= 1e-12:
                continue  # 오목한 꼭짓점
            inside = False
            for q in p:
                if q in (a, b, c):
                    continue
                d1 = (b[0] - a[0]) * (q[1] - a[1]) - (b[1] - a[1]) * (q[0] - a[0])
                d2 = (c[0] - b[0]) * (q[1] - b[1]) - (c[1] - b[1]) * (q[0] - b[0])
                d3 = (a[0] - c[0]) * (q[1] - c[1]) - (a[1] - c[1]) * (q[0] - c[0])
                if d1 >= 0 and d2 >= 0 and d3 >= 0:
                    inside = True
                    break
            if inside:
                continue
            tris.append((a, b, c))
            p.pop(i)
            cut = True
            break
        if not cut:
            return []  # 자기교차 등
    if len(p) == 3:
        tris.append((p[0], p[1], p[2]))
    return tris


def _wedge(R, P, Q, y0, h):
    """직각 꼭짓점 R, 다리 끝 P·Q. 높이 h의 WedgePart 하나."""
    def sub(a, b):
        return (a[0] - b[0], 0.0, a[1] - b[1])

    def norm(v):
        L = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2)
        return (v[0] / L, v[1] / L, v[2] / L), L

    def cross(a, b):
        return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])

    Y, ly = norm(sub(Q, R))
    Z, lz = norm(sub(R, P))  # 로컬 −Z가 R→P
    X = cross(Y, Z)
    if X[1] < 0:  # X가 아래를 보면 P·Q 역할을 바꿈
        return _wedge(R, Q, P, y0, h)
    cx = R[0] + (Q[0] - R[0]) / 2 + (P[0] - R[0]) / 2
    cz = R[1] + (Q[1] - R[1]) / 2 + (P[1] - R[1]) / 2
    rot = [[X[0], Y[0], Z[0]], [X[1], Y[1], Z[1]], [X[2], Y[2], Z[2]]]
    return {"cls": "WedgePart", "pos": (cx, y0 + h / 2, cz), "size": (h, ly, lz), "rot": rot}


def wedges(tri, y0, h):
    """삼각기둥(바닥 y0, 높이 h)을 최장변에 수선을 내려 WedgePart 2개로."""
    a, b, c = tri
    edges = [(a, b, c), (b, c, a), (c, a, b)]
    p, q, r = max(edges, key=lambda e: math.dist(e[0], e[1]))  # p-q 최장변, r 맞은편
    dx, dz = q[0] - p[0], q[1] - p[1]
    t = ((r[0] - p[0]) * dx + (r[1] - p[1]) * dz) / (dx * dx + dz * dz)
    f = (p[0] + t * dx, p[1] + t * dz)  # 수선의 발
    out = []
    for end in (p, q):
        if math.dist(f, end) > 1e-6 and math.dist(f, r) > 1e-6:
            out.append(_wedge(f, end, r, y0, h))
    return out
