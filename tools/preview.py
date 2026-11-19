#!/usr/bin/env python3
"""BaseMap.model.json 미리보기 렌더러 (스튜디오 없이 확인용).

사용: python3 tools/preview.py OUT.png --eye x y z --look x y z [--fov 60] [--size 1280 720] [--labels]
간단한 z-버퍼 래스터라이저: 상자·원기둥·공을 면 단위로 그림. 글씨(SurfaceGui)는 --labels로 위치에 표시.
"""
import argparse
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"


def load_parts(path):
    m = json.load(open(path, encoding="utf-8"))
    parts, labels = [], []

    def walk(n):
        p = n.get("properties", {})
        if "CFrame" in p and "Size" in p:
            cf = p["CFrame"]["CFrame"]
            pos = np.array(cf["position"], float)
            rot = np.array(cf["orientation"], float)
            size = np.array(p["Size"], float)
            tr = p.get("Transparency", 0)
            if tr < 0.95:
                parts.append((pos, rot, size, np.array(p.get("Color", [0.7, 0.7, 0.7])), tr, p.get("Shape", "Block")))
            for ch in n.get("children", []):
                if ch.get("className") == "SurfaceGui":
                    txt = ch["children"][0]["properties"]["Text"]
                    labels.append((pos, txt))
        for ch in n.get("children", []):
            walk(ch)

    walk(m)
    return parts, labels


def box_tris(pos, rot, size, shape):
    """월드 좌표 삼각형 목록 (각 삼각형: 3x3), 법선"""
    hx, hy, hz = size / 2
    if shape == "Cylinder":  # 축 = 로컬 X
        n = 10
        r = min(hy, hz)
        ring = [(math.cos(2 * math.pi * i / n) * r, math.sin(2 * math.pi * i / n) * r) for i in range(n)]
        verts = [(-hx, y, z) for y, z in ring] + [(hx, y, z) for y, z in ring]
        faces = []
        for i in range(n):
            j = (i + 1) % n
            faces += [(i, j, n + j), (i, n + j, n + i)]
        for i in range(1, n - 1):
            faces += [(0, i + 1, i), (n, n + i, n + i + 1)]
    elif shape == "Ball":
        r = size / 2
        verts, faces = [], []
        st, sl = 6, 8
        for a in range(st + 1):
            th = math.pi * a / st
            for b in range(sl):
                ph = 2 * math.pi * b / sl
                verts.append((math.sin(th) * math.cos(ph) * r[0], math.cos(th) * r[1], math.sin(th) * math.sin(ph) * r[2]))
        for a in range(st):
            for b in range(sl):
                i0, i1 = a * sl + b, a * sl + (b + 1) % sl
                j0, j1 = i0 + sl, i1 + sl
                faces += [(i0, j0, i1), (i1, j0, j1)]
    else:
        # 큰 면은 잘게 나눠서 그림 (카메라 가까이·뒤로 걸친 면도 그려지게)
        tris = []
        cell = 12.0
        for axis in range(3):
            for sgn in (-1, 1):
                u, w = [i for i in range(3) if i != axis]
                nu = max(1, int(math.ceil(size[u] / cell)))
                nw = max(1, int(math.ceil(size[w] / cell)))
                for i in range(nu):
                    for j in range(nw):
                        corners = []
                        for di, dj in ((0, 0), (1, 0), (1, 1), (0, 1)):
                            c = [0.0, 0.0, 0.0]
                            c[axis] = sgn * size[axis] / 2
                            c[u] = -size[u] / 2 + size[u] * (i + di) / nu
                            c[w] = -size[w] / 2 + size[w] * (j + dj) / nw
                            corners.append(c)
                        cw = np.array(corners) @ rot.T + pos
                        tris += [cw[[0, 1, 2]], cw[[0, 2, 3]]]
        return tris
    v = np.array(verts) @ rot.T + pos
    return [v[list(f)] for f in faces]


def render(parts, labels, out, eye, look, fov=60, W=1280, H=720, show_labels=False):
    eye, look = np.array(eye, float), np.array(look, float)
    fwd = look - eye
    fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    f = 0.5 * H / math.tan(math.radians(fov) / 2)
    img = np.zeros((H, W, 3))
    # 하늘 그라데이션
    for y in range(H):
        t = y / H
        img[y] = (1 - t) * np.array([0.55, 0.75, 0.95]) + t * np.array([0.85, 0.9, 0.95])
    zbuf = np.full((H, W), np.inf)
    light = np.array([0.4, 0.8, 0.3])
    light /= np.linalg.norm(light)

    def project(p):
        d = p - eye
        x, y, z = d @ right, d @ up, d @ fwd
        return np.stack([W / 2 + f * x / z, H / 2 - f * y / z, z], axis=-1)

    opaque = [p for p in parts if p[4] < 0.3]
    trans = [p for p in parts if p[4] >= 0.3]
    for group, alpha in ((opaque, None), (trans, True)):
        for pos, rot, size, color, tr, shape in group:
            if np.linalg.norm(pos - eye) > 2500:
                continue
            for tri in box_tris(pos, rot, size, shape):
                n = np.cross(tri[1] - tri[0], tri[2] - tri[0])
                ln = np.linalg.norm(n)
                if ln < 1e-9:
                    continue
                n /= ln
                if n @ (tri[0] - eye) > 0:
                    n = -n  # 양면 그리기
                pr = project(tri)
                if (pr[:, 2] < 0.5).any():
                    continue
                x0, x1 = int(max(0, pr[:, 0].min())), int(min(W - 1, pr[:, 0].max()))
                y0, y1 = int(max(0, pr[:, 1].min())), int(min(H - 1, pr[:, 1].max()))
                if x0 > x1 or y0 > y1:
                    continue
                xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
                (ax, ay, az), (bx, by, bz), (cx, cy, cz) = pr
                den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
                if abs(den) < 1e-9:
                    continue
                w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
                w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
                w2 = 1 - w0 - w1
                inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
                if not inside.any():
                    continue
                z = 1 / (w0 / az + w1 / bz + w2 / cz)
                sub = zbuf[y0:y1 + 1, x0:x1 + 1]
                m = inside & (z < sub)
                shade = 0.55 + 0.45 * max(0.0, n @ light)
                col = np.clip(color * shade, 0, 1)
                region = img[y0:y1 + 1, x0:x1 + 1]
                if alpha:
                    a = 1 - tr
                    region[m] = region[m] * (1 - a) + col * a
                else:
                    region[m] = col
                    sub[m] = z[m]
    im = Image.fromarray((img * 255).astype(np.uint8))
    if show_labels and os.path.exists(FONT):
        draw = ImageDraw.Draw(im)
        font = ImageFont.truetype(FONT, 16)
        for pos, txt in labels:
            p = project(pos[None, :])[0]
            if p[2] > 1 and 0 <= p[0] < W and 0 <= p[1] < H and p[2] < 400:
                if zbuf[int(p[1]), int(p[0])] + 3 >= p[2]:
                    draw.text((p[0], p[1]), txt.replace("\n", " "), font=font, fill=(20, 20, 20), anchor="mm",
                              stroke_width=2, stroke_fill=(255, 255, 255))
    im.save(out)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--eye", nargs=3, type=float, required=True)
    ap.add_argument("--look", nargs=3, type=float, required=True)
    ap.add_argument("--fov", type=float, default=60)
    ap.add_argument("--size", nargs=2, type=int, default=(1280, 720))
    ap.add_argument("--labels", action="store_true")
    ap.add_argument("--map", default=os.path.join(os.path.dirname(__file__), "..", "map", "BaseMap.model.json"))
    a = ap.parse_args()
    parts, labels = load_parts(a.map)
    render(parts, labels, a.out, a.eye, a.look, a.fov, a.size[0], a.size[1], a.labels)
    print("wrote", a.out)
