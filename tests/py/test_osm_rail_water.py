import os
import pytest
from osm.project import load, classify
from osm.rail_water import DECK_Y, rail_parts, platform_parts, water_luau

DATA = os.path.join(os.path.dirname(__file__), "..", "..", "data", "yangpyeong_station.osm")


@pytest.fixture(scope="module")
def data():
    return load(DATA)


def top(p):
    return p["pos"][1] + p["size"][1] / 2


def test_decks(data):
    decks = [p for p in rail_parts([w for w in data.ways if classify(w) == "rail"]) if p["name"].startswith("Deck")]
    assert len(decks) >= 10
    assert all(top(p) == pytest.approx(DECK_Y) for p in decks)


def test_water(data):
    s = water_luau([w for w in data.ways if classify(w) == "water"])
    assert "Enum.Material.Water" in s and "task.wait()" in s
    assert "64" in s  # 양근천 폭 40m × 1.6


def test_platforms(data):
    plats = [w for w in data.ways if classify(w) == "platform"]
    ps = [p for p in platform_parts(plats) if p["name"].startswith("Platform")]
    assert len(plats) == 8
    assert ps and all(top(p) == pytest.approx(DECK_Y + 2) for p in ps)
