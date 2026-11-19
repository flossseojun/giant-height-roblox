"""OSM 로드와 위경도 → 스터드 투영. 원점 = 양평역, +X 동쪽, −Z 북쪽."""
import math
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field

ORIGIN = (37.49285, 127.49190)
SCALE = 1.6  # 1m = 1.6 스터드
FLOOR = 7  # 1층 = 7 스터드
_M_PER_LAT = 110540.0
_M_PER_LON = 111320.0 * math.cos(math.radians(ORIGIN[0]))


def to_studs(lat: float, lon: float) -> tuple:
    x = (lon - ORIGIN[1]) * _M_PER_LON * SCALE
    z = -(lat - ORIGIN[0]) * _M_PER_LAT * SCALE
    return (x, z)


@dataclass
class Way:
    id: int
    tags: dict
    pts: list
    closed: bool


@dataclass
class OsmData:
    ways: list = field(default_factory=list)
    nodes: dict = field(default_factory=dict)  # id -> (x, z, tags)


def load(path: str) -> OsmData:
    root = ET.parse(path).getroot()
    d = OsmData()
    for n in root.iter("node"):
        tags = {t.get("k"): t.get("v") for t in n.findall("tag")}
        x, z = to_studs(float(n.get("lat")), float(n.get("lon")))
        d.nodes[n.get("id")] = (x, z, tags)
    for w in root.iter("way"):
        refs = [nd.get("ref") for nd in w.findall("nd")]
        pts = [(d.nodes[r][0], d.nodes[r][1]) for r in refs if r in d.nodes]
        if len(pts) < 2:
            continue
        tags = {t.get("k"): t.get("v") for t in w.findall("tag")}
        d.ways.append(Way(int(w.get("id")), tags, pts, refs[0] == refs[-1]))
    return d


def classify(way: Way) -> str:
    t = way.tags
    if t.get("building") == "train_station":
        return "station"
    if "building" in t:
        return "building"
    if t.get("railway") == "platform":
        return "platform"
    if t.get("railway") == "rail":
        return "rail"
    if t.get("waterway") or t.get("natural") == "water":
        return "water"
    if "highway" in t:
        return "road"
    if t.get("landuse") in ("grass", "forest", "village_green", "flowerbed", "farmland", "meadow") or \
            t.get("leisure") in ("park", "pitch", "playground", "garden"):
        return "green"
    return "other"
