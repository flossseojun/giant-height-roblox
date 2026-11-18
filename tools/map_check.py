#!/usr/bin/env python3
"""맵에 코드가 기대하는 태그가 구역별로 다 있는지 검사. 실행: python3 tools/map_check.py"""
import json
import os
import sys
from collections import Counter

here = os.path.dirname(os.path.abspath(__file__))
model = json.load(open(os.path.join(here, "..", "map", "BaseMap.model.json"), encoding="utf-8"))

count = Counter()


def walk(node):
    tags = node.get("properties", {}).get("Tags", [])
    zone = node.get("attributes", {}).get("Zone")
    for t in tags:
        count[(t, zone)] += 1
    for c in node.get("children", []):
        walk(c)


walk(model)

expected = {}
for z in (1, 2, 3):
    expected.update({("FoodSpawn", z): 20, ("ZoneArea", z): 1, ("MilkRainSpot", z): 1, ("Hoop", z): 1,
                     ("BallRack", z): 1, ("Bar", z): 1, ("Bed", z): 2})
expected.update({("ZoneGate", 2): 1, ("ZoneGate", 3): 1, ("GlobalBoard", None): 1})

bad = [(k, v, count.get(k, 0)) for k, v in expected.items() if count.get(k, 0) != v]
extra = [k for k in count if k not in expected]
for k, want, got in bad:
    print(f"FAIL {k}: want {want}, got {got}")
for k in extra:
    print(f"FAIL unexpected tag {k}")
print("map ok" if not bad and not extra else "map BAD")
sys.exit(1 if bad or extra else 0)
