import math
import pytest
from osm.geom import min_rect, rectangularity, triangulate, wedges, poly_area


def rot(pts, a):
    c, s = math.cos(a), math.sin(a)
    return [(x * c - z * s, x * s + z * c) for x, z in pts]


def test_min_rect_rotated():
    pts = rot([(-5, -2), (5, -2), (5, 2), (-5, 2)], math.radians(30))
    cx, cz, w, d, yaw = min_rect(pts)
    assert sorted([w, d]) == pytest.approx([4, 10], abs=0.01)
    assert cx == pytest.approx(0, abs=1e-6) and cz == pytest.approx(0, abs=1e-6)
    m = math.degrees(yaw) % 90
    assert min(abs(m - 30), abs(m - 30 + 90), abs(m - 30 - 90)) < 0.5


L = [(0, 0), (2, 0), (2, 1), (1, 1), (1, 2), (0, 2)]


def test_l_shape():
    assert rectangularity(L) == pytest.approx(0.75, abs=1e-6)
    tris = triangulate(L)
    assert sum(poly_area(list(t)) for t in tris) == pytest.approx(3, abs=1e-6)
    assert triangulate(list(reversed(L))) and sum(poly_area(list(t)) for t in triangulate(list(reversed(L)))) == pytest.approx(3)


def test_degenerate_polygon_falls_back():
    assert triangulate([(0, 0), (1, 1), (2, 2)]) == []
    assert triangulate([(1, 1), (1, 1), (1, 1)]) == []


def test_wedges_right_triangle():
    ws = wedges(((0, 0), (4, 0), (0, 3)), 0, 7)
    assert len(ws) == 2
    assert all(w["cls"] == "WedgePart" for w in ws)
    # WedgePart: 삼각 단면은 로컬 YZ, 늘어나는 축은 로컬 X → 높이 = size.x
    assert all(w["size"][0] == pytest.approx(7) for w in ws)
    assert sum(w["size"][1] * w["size"][2] / 2 for w in ws) == pytest.approx(6, abs=1e-6)
    # 로컬 X축(회전행렬 첫 열)이 세로(월드 Y)
    for w in ws:
        r = w["rot"]
        assert abs(r[1][0]) == pytest.approx(1, abs=1e-6)
