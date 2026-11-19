import os
import pytest
from osm.project import load, Way
from osm.roads import road_width_m, road_parts

DATA = os.path.join(os.path.dirname(__file__), "..", "..", "data", "yangpyeong_station.osm")


def test_widths():
    assert road_width_m({"highway": "tertiary", "lanes": "4"}) == 14
    assert road_width_m({"highway": "service"}) == 3.5
    assert road_width_m({"highway": "footway"}) == 2.5


def test_segment_box():
    w = Way(1, {"highway": "residential"}, [(0, 0), (100, 0)], False)
    seg = [p for p in road_parts(w) if p["name"].startswith("Road")]
    assert len(seg) == 1
    assert max(seg[0]["size"][0], seg[0]["size"][2]) == pytest.approx(100)
    assert min(seg[0]["size"][0], seg[0]["size"][2]) == pytest.approx(5 * 1.6)


def test_centerline_on_yeokjeongil():
    d = load(DATA)
    w = next(w for w in d.ways if w.tags.get("name") == "역전길" and w.tags.get("lanes") == "4")
    assert any(p["name"].startswith("CenterLine") for p in road_parts(w))
