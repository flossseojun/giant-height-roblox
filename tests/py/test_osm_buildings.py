import os
import pytest
from osm.project import load, classify, Way
from osm.buildings import floors, building_parts

DATA = os.path.join(os.path.dirname(__file__), "..", "..", "data", "yangpyeong_station.osm")


def test_floors():
    assert floors({"building:levels": "38"}, 1) == 38
    assert floors({"building": "house"}, 5) == 2
    assert floors({"building": "apartments"}, 9) == 15
    a = floors({"building": "yes"}, 777)
    assert a == floors({"building": "yes"}, 777) and a in (2, 3)


@pytest.fixture(scope="module")
def data():
    return load(DATA)


def body(parts):
    return [p for p in parts if p["name"].startswith("Body")]


def test_ostar_height(data):
    w = next(w for w in data.ways if w.tags.get("name") == "현대성우오스타코아루아파트")
    b = body(building_parts(w))
    top = max(p["pos"][1] + (p["size"][0] if p["cls"] == "WedgePart" else p["size"][1]) / 2 for p in b)
    assert top == pytest.approx(266, abs=0.01)


def test_rect_is_one_box():
    w = Way(5, {"building": "yes"}, [(0, 0), (20, 0), (20, 10), (0, 10), (0, 0)], True)
    b = body(building_parts(w))
    assert len(b) == 1 and b[0]["cls"] == "Part"


def test_l_is_wedges():
    L = [(0, 0), (40, 0), (40, 20), (20, 20), (20, 40), (0, 40), (0, 0)]
    b = body(building_parts(Way(6, {"building": "yes"}, L, True)))
    assert b and all(p["cls"] == "WedgePart" for p in b)
