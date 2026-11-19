import math, os
import pytest
from osm.project import ORIGIN, SCALE, FLOOR, to_studs, load, classify, Way

DATA = os.path.join(os.path.dirname(__file__), "..", "..", "data", "yangpyeong_station.osm")
M_LAT = 1 / 110540
M_LON = 1 / (111320 * math.cos(math.radians(ORIGIN[0])))


def test_origin():
    assert to_studs(*ORIGIN) == pytest.approx((0, 0))


def test_east_and_north():
    x, z = to_studs(ORIGIN[0], ORIGIN[1] + 100 * M_LON)
    assert x == pytest.approx(160, abs=0.5) and z == pytest.approx(0, abs=0.5)
    x, z = to_studs(ORIGIN[0] + 100 * M_LAT, ORIGIN[1])
    assert z == pytest.approx(-160, abs=0.5) and x == pytest.approx(0, abs=0.5)


@pytest.fixture(scope="module")
def data():
    return load(DATA)


def test_load_counts(data):
    kinds = [classify(w) for w in data.ways]
    assert kinds.count("building") >= 700
    st = [w for w in data.ways if classify(w) == "station"]
    assert len(st) == 1
    cx = sum(p[0] for p in st[0].pts) / len(st[0].pts)
    cz = sum(p[1] for p in st[0].pts) / len(st[0].pts)
    assert math.hypot(cx, cz) < 120
    ostar = [w for w in data.ways if w.tags.get("name") == "현대성우오스타코아루아파트"]
    assert ostar and ostar[0].tags["building:levels"] == "38"


def test_classify():
    mk = lambda t: Way(1, t, [(0, 0), (1, 1)], False)
    assert classify(mk({"waterway": "stream"})) == "water"
    assert classify(mk({"highway": "tertiary"})) == "road"
    assert classify(mk({"railway": "platform"})) == "platform"
    assert classify(mk({"building": "train_station"})) == "station"
