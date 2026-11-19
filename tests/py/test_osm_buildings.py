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


def test_downtown_shop_has_storefront_and_sign():
    w = Way(11, {"building": "yes"}, [(0, 0), (20, 0), (20, 14), (0, 14), (0, 0)], True)
    parts = building_parts(w, {"street": (10, -20), "downtown": True})
    names = [p["name"] for p in parts]
    assert "Storefront" in names and "SignBand" in names
    sign = next(p for p in parts if p["name"] == "SignBand")
    assert sign["label"][1] == "Front" and sign["pos"][2] < 0  # 도로(-Z) 쪽 면


def test_house_has_windows_every_floor_and_no_extra_body():
    w = Way(12, {"building": "house"}, [(0, 0), (16, 0), (16, 10), (0, 10), (0, 0)], True)
    parts = building_parts(w, {"street": (8, 30), "downtown": False})
    assert len(body(parts)) == 1
    assert {p["name"].split("_")[0] for p in parts if p["name"].startswith("Win")} == {"Win0", "Win1"}
