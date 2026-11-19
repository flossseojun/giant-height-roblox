"""1구역 '양평읍' — 양평역·물맑은시장·동네를 파트로 만든다. genmap.py가 불러 씀.

좌표: 1구역 바닥 x -480..120, z -300..140, 바닥 윗면 y=0. 1 스터드 ≈ 0.34m (캐릭터 5스터드 ≈ 1.7m).
배치(북쪽이 +z):
  z 55..85    고가 철로(경의중앙선) — 그 아래 x -420..-160 은 5일장 장터
  z 15..50    양평역 역사 (x -70..50), 서쪽에 승강장으로 올라가는 계단
  z -55..15   역 광장 (스폰), 버스정류장·택시
  z -85..-55  역전길(동서 도로)
  x -150..-135 남북 도로 (시장·강으로)
  x -360..-180, z -230..-110  물맑은시장 상설시장(지붕 덮인 골목)
  z -300..-250 남한강·강변 산책로, 서쪽은 공원(농구·철봉·침대)
"""
import math
import random

R = random.Random(11)


def Rx(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def Ry(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def Rz(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def build(h):
    """h: genmap의 도우미 묶음 (part, deco, sign, tree, folder, surface_text, rgb, CYL_UP)"""
    part, deco, sign, tree, folder, surface_text, rgb, CYL = (
        h["part"], h["deco"], h["sign"], h["tree"], h["folder"], h["surface_text"], h["rgb"], h["CYL_UP"])
    avoid = []
    groups = {}

    def add(group, p):
        groups.setdefault(group, []).append(p)

    def solid(group, name, x0, x1, z0, z1, y0, y1, color, material="SmoothPlastic", block=True, **kw):
        """x/z/y 범위로 상자 하나 (음식이 안 생기게 막을지 block)"""
        p = deco(name, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), color, material,
                 extra={"CanQuery": True}, **kw)
        add(group, p)
        if block:
            avoid.append((x0 - 2, x1 + 2, z0 - 2, z1 + 2))
        return p

    def flat(group, name, x0, x1, z0, z1, y, color, material="SmoothPlastic", thick=0.2, **kw):
        add(group, deco(name, ((x0 + x1) / 2, y + thick / 2, (z0 + z1) / 2), (x1 - x0, thick, z1 - z0), color,
                        material, collide=False, **kw))

    def label(group, name, pos, size, text, bg, fg=rgb(255, 255, 255), face="Front", orient=None, ppu=14):
        add(group, deco(name, pos, size, bg, orient=orient, children=[surface_text(text, face, fg, ppu=ppu)]))

    WHITE, CONC, DARK = rgb(240, 240, 238), rgb(170, 170, 165), rgb(55, 55, 60)
    GLASS, TEAL = rgb(120, 170, 200), rgb(70, 175, 150)  # 경의중앙선 색

    # ------------------------------------------------------------- 고가 철로 + 승강장 + 전동차
    DECK = 18
    solid("Railway", "Deck", -480, 115, 55, 85, DECK - 3, DECK, CONC, "Concrete", block=False)
    solid("Railway", "ParapetN", -480, 115, 84, 85, DECK, DECK + 1.6, CONC, "Concrete", block=False)
    for i, x in enumerate(range(-470, 115, 40)):
        for zz in (60, 80):
            solid("Railway", f"Pillar{i}_{zz}", x - 2, x + 2, zz - 2, zz + 2, 0, DECK - 3, rgb(150, 150, 145), "Concrete")
    for t, zc in enumerate((72, 80)):
        flat("Railway", f"Ballast{t}", -480, 115, zc - 3.5, zc + 3.5, DECK, rgb(110, 105, 100), "Slate", thick=0.6)
        for side in (-1.2, 1.2):
            flat("Railway", f"Rail{t}{side}", -480, 115, zc + side - 0.15, zc + side + 0.15, DECK + 0.6, rgb(90, 90, 95),
                 "Metal", thick=0.4)
    # 승강장 (역 북쪽, 철로 남쪽 절반)
    PL = DECK + 2
    solid("Platform", "PlatformSlab", -100, 60, 55, 67, DECK, PL, rgb(200, 200, 195), "Concrete", block=False)
    flat("Platform", "YellowLine", -100, 60, 65.5, 66.5, PL, rgb(250, 210, 40))
    for i, x in enumerate(range(-96, 60, 16)):
        add("Platform", deco(f"CanopyPost{i}", (x, PL + 6, 58), (0.8, 12, 0.8), WHITE, "Metal"))
    add("Platform", deco("CanopyRoof", (-20, PL + 12.4, 61), (164, 0.8, 16), rgb(230, 235, 240), "Metal",
                         orient=Rx(math.radians(4))))
    for i, x in enumerate((-80, -20, 40)):
        label("Platform", f"StationNameBoard{i}", (x, PL + 7, 58.6), (18, 3.5, 0.4), "양평  Yangpyeong", WHITE,
              fg=rgb(30, 60, 120), face="Back")
        add("Platform", deco(f"BoardStripe{i}", (x, PL + 5.1, 58.6), (18, 0.4, 0.45), TEAL))
    for i, x in enumerate(range(-90, 60, 30)):
        add("Platform", deco(f"Bench{i}", (x, PL + 1, 57.5), (6, 0.6, 1.6), rgb(90, 140, 200)))
    # 전동차 2량 (흰 몸체 + 청록 띠)
    for c, x0 in enumerate((-95, -35)):
        x1 = x0 + 56
        zc = 72
        solid("Train", f"Car{c}Body", x0, x1, zc - 2.6, zc + 2.6, DECK + 1.2, DECK + 8, WHITE, "SmoothPlastic", block=False)
        add("Train", deco(f"Car{c}Window", ((x0 + x1) / 2, DECK + 5.6, zc), (x1 - x0 - 2, 1.8, 5.3), rgb(40, 50, 60),
                          "Glass"))
        add("Train", deco(f"Car{c}Stripe", ((x0 + x1) / 2, DECK + 3.4, zc), (x1 - x0 + 0.05, 0.7, 5.35), TEAL))
        add("Train", deco(f"Car{c}Stripe2", ((x0 + x1) / 2, DECK + 2.6, zc), (x1 - x0 + 0.05, 0.35, 5.35),
                          rgb(40, 120, 200)))
        for d in range(4):
            dx = x0 + 6 + d * 14.5
            add("Train", deco(f"Car{c}Door{d}", (dx, DECK + 4.4, zc - 2.62), (3, 6, 0.1), rgb(200, 205, 210)))
        add("Train", deco(f"Car{c}Roof", ((x0 + x1) / 2, DECK + 8.2, zc), (x1 - x0, 0.4, 4.6), rgb(200, 200, 205)))

    # ------------------------------------------------------------- 양평역 역사
    X0, X1, Z0, Z1, H = -70, 50, 15, 50, 19
    solid("Station", "Body", X0, X1, Z0 + 1, Z1, 0, H, rgb(225, 228, 232), "Concrete")
    # 남쪽 유리 커튼월 + 세로 프레임
    add("Station", deco("GlassWall", ((X0 + X1) / 2, 7, Z0 + 0.6), (X1 - X0 - 4, 13, 1), GLASS, "Glass",
                        transparent=0.25))
    for i, x in enumerate(range(X0 + 4, X1 - 1, 6)):
        add("Station", deco(f"Mullion{i}", (x, 7, Z0 + 0.3), (0.5, 13, 0.6), WHITE, "Metal"))
    add("Station", deco("UpperBand", ((X0 + X1) / 2, 16.5, Z0 + 0.4), (X1 - X0, 5, 0.8), rgb(45, 70, 120),
                        children=[surface_text("양평역", "Front", rgb(255, 255, 255), ppu=6)]))
    label("Station", "EnglishName", ((X0 + X1) / 2, 13.4, Z0 - 0.05), (40, 1.4, 0.3), "Yangpyeong Station  ·  K136",
          rgb(45, 70, 120), ppu=16)
    add("Station", deco("RoofCornice", ((X0 + X1) / 2, H + 0.5, (Z0 + Z1) / 2), (X1 - X0 + 2, 1, Z1 - Z0 + 2), WHITE,
                        "Metal"))
    # 출입구: 어두운 유리문 3개 + 캐노피
    for i, x in enumerate((-30, -10, 10)):
        add("Station", deco(f"Door{i}", (x, 4, Z0 + 0.1), (8, 8, 0.4), rgb(50, 70, 90), "Glass", transparent=0.2,
                            collide=False))
    add("Station", deco("EntranceCanopy", (-10, 11, Z0 - 4), (44, 0.8, 9), rgb(235, 235, 240), "Metal"))
    for i, x in enumerate((-31, 11)):
        add("Station", deco(f"CanopyPole{i}", (x, 5.5, Z0 - 8), (0.6, 11, 0.6), WHITE, "Metal"))
    # 경의중앙선 마크 (청록 원)
    add("Station", deco("LineLogo", (X0 + 6, 16.5, Z0 - 0.2), (0.4, 4.4, 4.4), TEAL, "Neon", shape="Cylinder",
                        orient=[[0, 0, -1], [0, 1, 0], [1, 0, 0]],
                        children=[surface_text("K136", "Right", rgb(255, 255, 255), ppu=10)]))
    # 역 이름 기둥 (입구 동쪽)
    add("Station", deco("NamePylon", (34, 11, Z0 - 10), (3.4, 22, 3.4), rgb(45, 70, 120),
                        children=[surface_text("양\n평\n역", "Front", rgb(255, 255, 255), ppu=8),
                                  surface_text("양\n평\n역", "Back", rgb(255, 255, 255), ppu=8)]))
    add("Station", deco("PylonLogo", (34, 23.2, Z0 - 10), (3.6, 2.4, 3.6), TEAL, "Neon"))
    avoid.append((30, 38, Z0 - 14, Z0 - 6))
    # 승강장으로 올라가는 계단 (역사 서쪽)
    for s in range(20):
        x0 = -110 + s * 1.5
        solid("StationStairs", f"Step{s}", x0, x0 + 1.5, 40, 50, 0, s + 1, rgb(190, 190, 185), "Concrete", block=False)
    solid("StationStairs", "Landing", -80, -70, 40, 55, 0, 20, rgb(190, 190, 185), "Concrete")
    for s in range(2):
        add("StationStairs", deco(f"Rail{s}", (-95, 11, 40 + s * 10), (30, 0.3, 0.3), rgb(120, 120, 125), "Metal",
                                  orient=Rz(math.atan2(20, 30))))
    avoid.append((-112, -68, 38, 57))

    # ------------------------------------------------------------- 역 광장
    tiles = [rgb(205, 200, 190), rgb(185, 180, 172)]
    for i, x in enumerate(range(-80, 60, 10)):
        for j, zz in enumerate(range(-55, 15, 10)):
            flat("Plaza", f"Tile{i}_{j}", x, x + 10, zz, zz + 10, 0, tiles[(i + j) % 2], "Slate", thick=0.15)
    for i, (x, zz) in enumerate(((-60, -35), (40, -35), (-60, -5), (40, -5))):
        solid("Plaza", f"FlowerBed{i}", x - 7, x + 7, zz - 4, zz + 4, 0, 1.6, rgb(150, 110, 80), "Brick")
        flat("Plaza", f"Soil{i}", x - 6.5, x + 6.5, zz - 3.5, zz + 3.5, 1.6, rgb(70, 130, 60), "Grass")
        for k in range(6):
            add("Plaza", deco(f"Flower{i}_{k}", (x - 5 + k * 2, 2.3, zz + R.uniform(-2.5, 2.5)), (1.2, 1.2, 1.2),
                              [rgb(255, 110, 140), rgb(255, 220, 80), rgb(200, 120, 255)][k % 3], shape="Ball",
                              collide=False))
    for i, x in enumerate((-75, -40, 20, 55)):
        add("Plaza", deco(f"Lamp{i}", (x, 7, -52), (0.6, 14, 0.6), DARK, "Metal"))
        add("Plaza", deco(f"LampHead{i}", (x, 14.2, -52), (2.4, 0.8, 2.4), rgb(255, 245, 200), "Neon"))
        avoid.append((x - 2, x + 2, -54, -50))
    for i, x in enumerate((-50, 30)):
        add("Plaza", deco(f"Bench{i}", (x, 1, -20), (8, 0.8, 2), rgb(150, 100, 60), "Wood"))
    add("Plaza", tree("PlazaTree1", (-75, 0, 5), 12, 2, 14, rgb(80, 150, 70)))
    add("Plaza", tree("PlazaTree2", (55, 0, 5), 12, 2, 14, rgb(80, 150, 70)))
    avoid += [(-80, -70, 0, 10), (50, 60, 0, 10)]
    # 버스 정류장 2곳 (광장 남쪽 길가)
    for i, x in enumerate((-55, 25)):
        solid("BusStop", f"Shelter{i}Back", x - 7, x + 7, -54, -53.4, 0, 8, GLASS, "Glass", transparent=0.4)
        add("BusStop", deco(f"Shelter{i}Roof", (x, 8.3, -51.5), (15, 0.5, 5), rgb(60, 150, 90), "Metal"))
        add("BusStop", deco(f"Shelter{i}Bench", (x, 1.2, -52.6), (10, 0.5, 1.4), rgb(200, 200, 205), "Metal"))
        label("BusStop", f"Shelter{i}Sign", (x + 6.8, 6, -51.5), (0.3, 3, 4), "버스", rgb(60, 150, 90), face="Right",
              ppu=12)
    # 택시 승강장 + 택시
    label("Taxi", "TaxiSign", (-5, 6, -54), (6, 2.5, 0.3), "TAXI 택시", rgb(250, 190, 40), fg=rgb(30, 30, 30),
          face="Back", ppu=12)

    def car(group, name, x, zc, color, yaw=0.0, taxi=False):
        o = Ry(yaw)
        c, s = math.cos(yaw), math.sin(yaw)

        def at(dx, dz):
            return (x + dx * c + dz * s, zc - dx * s + dz * c)

        bx, bz = at(0, 0)
        add(group, deco(name + "Body", (bx, 1.9, bz), (5.4, 2.2, 12), color, orient=o))
        cx_, cz_ = at(0, 0.6)
        add(group, deco(name + "Cabin", (cx_, 3.9, cz_), (5, 1.8, 6.5), rgb(60, 70, 85), "Glass", orient=o))
        for wx, wz in ((-2.6, -3.8), (2.6, -3.8), (-2.6, 3.8), (2.6, 3.8)):
            px, pz = at(wx, wz)
            add(group, deco(name + "Wheel", (px, 1, pz), (0.8, 2, 2), rgb(25, 25, 25), shape="Cylinder", orient=o))
        if taxi:
            tx, tz = at(0, 0.6)
            add(group, deco(name + "TaxiLamp", (tx, 5.1, tz), (2, 0.6, 1), rgb(255, 230, 120), "Neon", orient=o))
        avoid.append((bx - 7, bx + 7, bz - 7, bz + 7))

    car("Taxi", "Taxi1", -9, -66, rgb(240, 150, 40), 0, taxi=True)
    car("Taxi", "Taxi2", 3, -66, rgb(235, 235, 235), 0, taxi=True)

    # ------------------------------------------------------------- 도로
    ASPH, SIDE = rgb(70, 70, 75), rgb(195, 190, 180)
    flat("Road", "Yeokjeongil", -480, 115, -80, -58, 0, ASPH, "Asphalt", thick=0.18)
    flat("Road", "SidewalkS", -480, 115, -86, -80, 0, SIDE, "Slate", thick=0.3)
    flat("Road", "CenterLine", -480, 115, -69.4, -68.6, 0.18, rgb(250, 200, 40), thick=0.05)
    for i, x in enumerate(range(-470, 110, 14)):
        flat("Road", f"LaneDash{i}", x, x + 6, -74.3, -73.7, 0.18, WHITE, thick=0.05)
        flat("Road", f"LaneDashB{i}", x, x + 6, -63.8, -63.2, 0.18, WHITE, thick=0.05)
    for k in range(8):  # 횡단보도 (역 앞)
        flat("Road", f"Zebra{k}", -16 + k * 2.6, -14.6 + k * 2.6, -79, -59, 0.18, WHITE, thick=0.06)
    flat("Road", "SouthRoad", -150, -135, -300, 55, 0, ASPH, "Asphalt", thick=0.18)
    flat("Road", "SouthRoadLine", -142.8, -142.2, -250, 50, 0.18, rgb(250, 200, 40), thick=0.05)
    for k in range(6):
        flat("Road", f"Zebra2_{k}", -150, -135, -100 + k * 2.6, -98.6 + k * 2.6, 0.18, WHITE, thick=0.06)
    car("Road", "Car1", -260, -64, rgb(60, 90, 180), 0)
    car("Road", "Car2", 80, -75, rgb(200, 60, 60), math.pi)
    car("Road", "Car3", -142, -150, rgb(230, 230, 230), math.pi / 2)
    # 시내버스
    add("Road", deco("BusBody", (-120, 4.8, -64), (32, 8, 7), rgb(70, 170, 90), orient=Ry(math.pi / 2)))
    add("Road", deco("BusWindows", (-120, 6.3, -64), (32.1, 2.4, 7.1), rgb(40, 50, 60), "Glass", orient=Ry(math.pi / 2)))
    avoid.append((-138, -102, -70, -58))

    # ------------------------------------------------------------- 동네 상가 건물
    FACADES = [rgb(235, 225, 205), rgb(215, 205, 190), rgb(180, 110, 90), rgb(240, 240, 235), rgb(200, 215, 225),
               rgb(225, 200, 160)]
    SIGNS = ["양평약국", "카페", "편의점", "분식", "치킨", "미용실", "양평한우", "PC방", "빵집", "문구점", "꽃집", "안경",
             "은행", "학원", "병원", "옷가게"]
    sign_i = [0]

    def building(name, x0, x1, z0, z1, floors, face):
        """face: 간판·창문이 향하는 쪽 'S'(−z) 또는 'N'(+z)"""
        hgt = floors * 9
        color = FACADES[R.randrange(len(FACADES))]
        solid("Town", name, x0, x1, z0, z1, 0, hgt, color, "Concrete")
        fz = z0 - 0.2 if face == "S" else z1 + 0.2
        for f in range(1, floors):
            add("Town", deco(f"{name}Win{f}", ((x0 + x1) / 2, f * 9 + 4.5, fz), (x1 - x0 - 3, 3.5, 0.4),
                             rgb(70, 95, 120), "Glass"))
        txt = SIGNS[sign_i[0] % len(SIGNS)]
        sign_i[0] += 1
        sc = [rgb(220, 60, 60), rgb(40, 110, 200), rgb(40, 160, 90), rgb(240, 160, 30), rgb(120, 70, 170)][sign_i[0] % 5]
        add("Town", deco(f"{name}Shop", ((x0 + x1) / 2, 3.5, fz), (x1 - x0 - 4, 6, 0.4), rgb(90, 120, 140), "Glass",
                         transparent=0.3))
        label("Town", f"{name}Sign", ((x0 + x1) / 2, 7.8, fz + (-0.3 if face == "S" else 0.3)), (x1 - x0 - 2, 2.4, 0.4),
              txt, sc, face="Front" if face == "S" else "Back", ppu=14)
        add("Town", deco(f"{name}Roof", ((x0 + x1) / 2, hgt + 0.4, (z0 + z1) / 2), (x1 - x0 + 0.6, 0.8, z1 - z0 + 0.6),
                         rgb(110, 110, 115)))

    # 역전길 남쪽 상가 줄
    x = -130
    k = 0
    while x < 110:
        w = R.choice((18, 20, 22, 24))
        if not (-150 <= x <= -134 or -150 <= x + w <= -134):
            building(f"SouthRow{k}", x, x + w, -110, -90, R.choice((2, 3, 3, 4)), "N")
            k += 1
        x += w + 3
    # 광장 동쪽 · 서쪽
    building("EastA", 64, 88, -48, -18, 4, "S")
    building("EastB", 92, 114, -48, -18, 3, "S")
    building("EastC", 64, 112, -12, 10, 2, "S")
    building("WestA", -128, -104, -48, -20, 3, "S")
    building("WestB", -128, -104, -14, 10, 2, "S")

    # ------------------------------------------------------------- 아파트 단지 (강 쪽 동남부)
    def apartment(name, x0, x1, z0, z1, floors, label_txt):
        hgt = floors * 9
        solid("Apartments", name, x0, x1, z0, z1, 0, hgt, rgb(238, 236, 230), "Concrete")
        for f in range(1, floors):
            for face_z, nm in ((z0 - 0.2, "S"), (z1 + 0.2, "N")):
                add("Apartments", deco(f"{name}Win{f}{nm}", ((x0 + x1) / 2, f * 9 + 4, face_z), (x1 - x0 - 2, 3, 0.4),
                                       rgb(90, 120, 150), "Glass"))
            add("Apartments", deco(f"{name}Bal{f}", ((x0 + x1) / 2, f * 9 + 1.6, z0 - 0.6), (x1 - x0 - 2, 0.5, 1.2),
                                   rgb(210, 210, 205)))
        add("Apartments", deco(f"{name}Stripe", ((x0 + x1) / 2, hgt - 4, z0 - 0.3), (x1 - x0, 3, 0.4),
                               rgb(60, 140, 120)))
        label("Apartments", f"{name}Label", ((x0 + x1) / 2, hgt - 4, z0 - 0.55), (24, 2.6, 0.2), label_txt,
              rgb(60, 140, 120), ppu=12)
        add("Apartments", deco(f"{name}Roof", ((x0 + x1) / 2, hgt + 1, (z0 + z1) / 2), (x1 - x0, 2, z1 - z0),
                               rgb(120, 110, 105)))

    apartment("AptA", -100, -40, -200, -180, 9, "양평 강변 101동")
    apartment("AptB", -20, 40, -200, -180, 11, "양평 강변 102동")
    apartment("AptC", -100, -40, -150, -130, 8, "양평 강변 103동")
    flat("Apartments", "AptGrounds", -110, 50, -235, -120, 0, rgb(110, 165, 95), "Grass", thick=0.15)
    for i, x in enumerate(range(-105, 50, 22)):
        add("Apartments", tree(f"AptTree{i}", (x, 0, -225), 9, 1.4, 10, rgb(80, 150, 75)))
        avoid.append((x - 4, x + 4, -229, -221))
    # 양평군청
    solid("Gunchung", "GunchungBody", 60, 112, -230, -170, 0, 32, rgb(225, 220, 210), "Concrete")
    add("Gunchung", deco("GunchungGlass", (86, 16, -230.3), (40, 26, 0.5), rgb(90, 120, 150), "Glass"))
    add("Gunchung", deco("GunchungRoof", (86, 33, -200), (56, 2, 64), rgb(110, 95, 85)))
    label("Gunchung", "GunchungSign", (86, 29, -230.6), (30, 3.5, 0.3), "양평군청", rgb(40, 80, 140), ppu=12)
    add("Gunchung", deco("FlagPole", (66, 12, -238), (0.5, 24, 0.5), rgb(200, 200, 205), "Metal"))
    add("Gunchung", deco("Flag", (68.5, 22, -238), (4.5, 3, 0.15), rgb(250, 250, 250), "Fabric"))
    avoid.append((64, 70, -242, -234))
    # 장터 마당 주차장 (보스·우유 비 자리 주변, 길 북쪽 서편)
    flat("Parking", "ParkingLot", -360, -160, -50, 40, 0, rgb(80, 80, 85), "Asphalt", thick=0.15)
    for i, x in enumerate(range(-356, -160, 9)):
        flat("Parking", f"ParkLine{i}", x, x + 0.4, 25, 40, 0.15, WHITE, thick=0.04)
        flat("Parking", f"ParkLineS{i}", x, x + 0.4, -50, -35, 0.15, WHITE, thick=0.04)
    for i, x in enumerate((-342, -315, -297, -270, -225, -198, -180)):
        car("Parking", f"Parked{i}", x + 4.5, 32, [rgb(230, 230, 230), rgb(40, 40, 45), rgb(150, 30, 30),
                                                    rgb(60, 90, 160)][i % 4], 0)
    label("Parking", "ParkingSign", (-160.5, 5, -10), (0.3, 4, 8), "P 장터 주차장", rgb(30, 90, 200), face="Right", ppu=12)
    # 서쪽 주택가 (길 북쪽, 철로 남쪽, 보스 마당 서편)
    for i, (x0, z0) in enumerate(((-478, -50), (-478, -20), (-478, 10))):
        solid("Houses", f"House{i}", x0, x0 + 22, z0, z0 + 20, 0, 12, FACADES[(i + 2) % len(FACADES)], "Brick")
        add("Houses", deco(f"HouseRoof{i}", (x0 + 11, 14, z0 + 10), (24, 0.8, 22), rgb(160, 70, 60), "Slate",
                           orient=Rx(math.radians(8))))
    # ------------------------------------------------------------- 물맑은시장 (상설시장)
    MX0, MX1, MZ0, MZ1 = -360, -180, -230, -110
    AX0, AX1 = -277, -263  # 남북 골목
    CZ0, CZ1 = -177, -163  # 동서 골목
    SHOPS = ["양평해장국", "국수", "녹두전", "수수부꾸미", "떡집", "채소", "과일", "정육점", "생선", "방앗간", "반찬", "건어물",
             "그릇", "약초", "참기름", "순대", "닭강정", "호떡", "옷가게", "잡화", "두부", "산나물", "김밥", "만두"]
    shop_colors = [rgb(220, 70, 60), rgb(240, 160, 30), rgb(50, 130, 210), rgb(60, 160, 90), rgb(150, 80, 180),
                   rgb(230, 100, 140)]
    si = 0

    def shop_row(name, x0, x1, z0, z1, facing):
        nonlocal si
        # facing: 가게 앞이 향하는 방향 'N','S','E','W'
        along_x = facing in ("N", "S")
        a0, a1 = (x0, x1) if along_x else (z0, z1)
        n = max(1, int((a1 - a0) // 12))
        unit = (a1 - a0) / n
        for u in range(n):
            b0, b1 = a0 + u * unit, a0 + (u + 1) * unit
            ux0, ux1, uz0, uz1 = (b0, b1, z0, z1) if along_x else (x0, x1, b0, b1)
            body_col = rgb(225, 215, 195) if u % 2 == 0 else rgb(210, 200, 182)
            solid("Market", f"{name}Unit{u}", ux0 + 0.3, ux1 - 0.3, uz0, uz1, 0, 13, body_col, "Concrete")
            txt = SHOPS[si % len(SHOPS)]
            col = shop_colors[si % len(shop_colors)]
            si += 1
            mid = ((ux0 + ux1) / 2, (uz0 + uz1) / 2)
            if facing == "N":
                pos, size, face, frontz = (mid[0], 10.5, uz1 + 0.3), (unit - 1.2, 2.6, 0.4), "Back", uz1 + 0.1
                opening = (mid[0], 4, frontz), (unit - 3, 7, 0.3)
                awn = (mid[0], 8.9, uz1 + 1.1), (unit - 2, 0.25, 2.2), Rx(math.radians(-10))
            elif facing == "S":
                pos, size, face, frontz = (mid[0], 10.5, uz0 - 0.3), (unit - 1.2, 2.6, 0.4), "Front", uz0 - 0.1
                opening = (mid[0], 4, frontz), (unit - 3, 7, 0.3)
                awn = (mid[0], 8.9, uz0 - 1.1), (unit - 2, 0.25, 2.2), Rx(math.radians(10))
            elif facing == "E":
                pos, size, face = (ux1 + 0.3, 10.5, mid[1]), (0.4, 2.6, unit - 1.2), "Right"
                opening = (ux1 + 0.1, 4, mid[1]), (0.3, 7, unit - 3)
                awn = (ux1 + 1.1, 8.9, mid[1]), (2.2, 0.25, unit - 2), Rz(math.radians(10))
            else:
                pos, size, face = (ux0 - 0.3, 10.5, mid[1]), (0.4, 2.6, unit - 1.2), "Left"
                opening = (ux0 - 0.1, 4, mid[1]), (0.3, 7, unit - 3)
                awn = (ux0 - 1.1, 8.9, mid[1]), (2.2, 0.25, unit - 2), Rz(math.radians(-10))
            label("Market", f"{name}Sign{u}", pos, size, txt, col, face=face, ppu=14)
            add("Market", deco(f"{name}Open{u}", opening[0], opening[1], rgb(60, 45, 35), collide=False))
            add("Market", deco(f"{name}Awning{u}", awn[0], awn[1], col, "Fabric", orient=awn[2], collide=False))
            # 가게 앞 진열대 + 물건
            gcol = [rgb(90, 170, 60), rgb(230, 70, 50), rgb(250, 170, 40), rgb(150, 60, 140)]
            if facing in ("N", "S"):
                tz = (uz1 + 2.2) if facing == "N" else (uz0 - 2.2)
                add("Market", deco(f"{name}Stall{u}", (mid[0], 1.5, tz), (unit - 4, 3, 2.4), rgb(150, 105, 65), "Wood"))
                for g in range(3):
                    add("Market", deco(f"{name}Goods{u}_{g}", (mid[0] - 3 + g * 3, 3.4, tz), (1.6, 1.6, 1.6),
                                       gcol[(si + g) % 4], shape="Ball", collide=False))
            else:
                tx = (ux1 + 2.2) if facing == "E" else (ux0 - 2.2)
                add("Market", deco(f"{name}Stall{u}", (tx, 1.5, mid[1]), (2.4, 3, unit - 4), rgb(150, 105, 65), "Wood"))
                for g in range(3):
                    add("Market", deco(f"{name}Goods{u}_{g}", (tx, 3.4, mid[1] - 3 + g * 3), (1.6, 1.6, 1.6),
                                       gcol[(si + g) % 4], shape="Ball", collide=False))

    # 네 구역의 가게 줄 (골목을 바라봄)
    shop_row("NW_E", AX0 - 12, AX0, CZ1, MZ1, "E")
    shop_row("NE_W", AX1, AX1 + 12, CZ1, MZ1, "W")
    shop_row("SW_E", AX0 - 12, AX0, MZ0, CZ0, "E")
    shop_row("SE_W", AX1, AX1 + 12, MZ0, CZ0, "W")
    shop_row("WN_S", MX0, AX0 - 12, CZ1, CZ1 + 12, "S")
    shop_row("WS_N", MX0, AX0 - 12, CZ0 - 12, CZ0, "N")
    shop_row("EN_S", AX1 + 12, MX1, CZ1, CZ1 + 12, "S")
    shop_row("ES_N", AX1 + 12, MX1, CZ0 - 12, CZ0, "N")
    # 골목 바닥 + 아치형 투명 지붕 + 철골 갈비뼈
    flat("Market", "AlleyNS", AX0, AX1, MZ0, MZ1, 0, rgb(160, 150, 140), "Slate", thick=0.2)
    flat("Market", "AlleyEW", MX0, MX1, CZ0, CZ1, 0, rgb(160, 150, 140), "Slate", thick=0.2)

    def arcade(name, x0, x1, z0, z1, along_z):
        w = (x1 - x0) if along_z else (z1 - z0)
        length = (z1 - z0) if along_z else (x1 - x0)
        mid = ((x0 + x1) / 2, (z0 + z1) / 2)
        a = math.radians(22)
        side_w = w * 0.36
        for sgn in (-1, 1):
            off = sgn * w * 0.32
            if along_z:
                pos, size, o = (mid[0] + off, 15.6, mid[1]), (side_w, 0.3, length), Rz(-sgn * a)
            else:
                pos, size, o = (mid[0], 15.6, mid[1] + off), (length, 0.3, side_w), Rx(sgn * a)
            add("Market", deco(f"{name}Roof{sgn}", pos, size, rgb(200, 225, 240), "Glass", transparent=0.45,
                               orient=o, collide=False))
        add("Market", deco(f"{name}RoofTop", (mid[0], 17.4, mid[1]),
                           (w * 0.34, 0.3, length) if along_z else (length, 0.3, w * 0.34), rgb(200, 225, 240), "Glass",
                           transparent=0.45, collide=False))
        n = int(length // 10)
        for r in range(n + 1):
            t = (z0 if along_z else x0) + r * length / n
            if along_z:
                add("Market", deco(f"{name}Rib{r}", (mid[0], 16.3, t), (w, 0.5, 0.5), rgb(120, 125, 135), "Metal",
                                   collide=False))
            else:
                add("Market", deco(f"{name}Rib{r}", (t, 16.3, mid[1]), (0.5, 0.5, w), rgb(120, 125, 135), "Metal",
                                   collide=False))

    arcade("ArcadeNS", AX0, AX1, MZ0, MZ1, True)
    arcade("ArcadeEW", MX0, MX1, CZ0, CZ1, False)
    # 시장 입구 문 (북쪽, 역 쪽을 바라봄) + 간판
    gx = (AX0 + AX1) / 2
    for s in (-1, 1):
        solid("Market", f"GatePillar{s}", gx + s * 9 - 1, gx + s * 9 + 1, MZ1 + 1, MZ1 + 3, 0, 20, rgb(120, 60, 50),
              "Wood")
    label("Market", "GateSign", (gx, 19, MZ1 + 2), (22, 4, 1), "양평물맑은시장", rgb(30, 90, 160), face="Back", ppu=12)
    label("Market", "GateSignS", (gx, 19, MZ1 + 2.01), (22, 4, 1), "양평물맑은시장", rgb(30, 90, 160), face="Front", ppu=12)
    label("Market", "MarketDayBanner", (MX1 + 0.3, 14, (CZ0 + CZ1) / 2), (0.4, 3, 14), "3·8일 장날", rgb(220, 60, 50),
          face="Right", ppu=12)
    # 물맑은시장 쉼터 (3층)
    solid("Market", "ShimteoBody", -420, -380, -150, -112, 0, 27, rgb(235, 230, 220), "Concrete")
    for f in (1, 2):
        add("Market", deco(f"ShimteoWin{f}", (-400, f * 9 + 4.5, -111.7), (36, 3.5, 0.4), rgb(70, 95, 120), "Glass"))
    label("Market", "ShimteoSign", (-400, 7.5, -111.6), (30, 3, 0.4), "물맑은시장 쉼터", rgb(40, 140, 120), face="Back",
          ppu=14)

    # ------------------------------------------------------------- 기찻길 아래 5일장
    TARPS = [rgb(40, 110, 200), rgb(240, 140, 40), rgb(220, 60, 60), rgb(60, 160, 90), rgb(250, 210, 60),
             rgb(240, 240, 240)]
    GOODS = [rgb(90, 170, 60), rgb(230, 70, 50), rgb(250, 170, 40), rgb(150, 60, 140), rgb(240, 230, 200),
             rgb(120, 80, 50)]
    t = 0
    for zc, face_dir in ((61, 1), (79, -1)):
        for x in range(-412, -165, 12):
            tc = TARPS[t % len(TARPS)]
            t += 1
            for px in (-4.5, 4.5):
                for pz in (-3.5, 3.5):
                    add("JangUnderRail", deco(f"Pole{t}", (x + px, 4, zc + pz), (0.3, 8, 0.3), rgb(120, 120, 120),
                                              "Metal", collide=False))
            add("JangUnderRail", deco(f"Tarp{t}", (x, 8.2, zc), (10, 0.3, 8), tc, "Fabric", collide=False,
                                      orient=Rx(math.radians(6 * face_dir))))
            add("JangUnderRail", deco(f"Table{t}", (x, 1.6, zc + face_dir * 1.5), (8.5, 0.4, 3.5), rgb(160, 115, 70),
                                      "Wood"))
            add("JangUnderRail", deco(f"TableLeg{t}", (x, 0.7, zc + face_dir * 1.5), (8, 1.4, 3), rgb(110, 80, 50),
                                      "Wood", transparent=0.5, collide=False))
            for g in range(4):
                add("JangUnderRail", deco(f"Crate{t}_{g}", (x - 3.2 + g * 2.1, 2.3, zc + face_dir * 1.5), (1.8, 1, 1.6),
                                          rgb(170, 120, 70), "Wood", collide=False))
                for b in range(2):
                    add("JangUnderRail", deco(f"Goods{t}_{g}_{b}", (x - 3.6 + g * 2.1 + b * 0.8, 3.1,
                                                                   zc + face_dir * 1.5), (0.8, 0.8, 0.8),
                                              GOODS[(t + g) % len(GOODS)], shape="Ball", collide=False))
            avoid.append((x - 5, x + 5, zc - 4, zc + 4))
    for i, x in enumerate((-400, -290, -180)):
        label("JangUnderRail", f"JangBanner{i}", (x, 12, 57.9), (20, 3, 0.4), "양평 5일장 (3·8일)", rgb(220, 60, 50),
              face="Front", ppu=14)

    # ------------------------------------------------------------- 남한강 + 강변 + 공원
    flat("River", "NamhanRiver", -480, 120, -300, -262, 0.05, WATER_COLOR, "Glass", thick=0.4, transparent=0.25)
    flat("River", "Promenade", -480, 120, -262, -250, 0, rgb(170, 130, 95), "WoodPlanks", thick=0.3)
    for i, x in enumerate(range(-476, 120, 8)):
        add("River", deco(f"RailPost{i}", (x, 1.8, -262.5), (0.4, 3.6, 0.4), rgb(90, 90, 95), "Metal"))
    add("River", deco("RailTop", (-180, 3.6, -262.5), (600, 0.3, 0.3), rgb(90, 90, 95), "Metal"))
    label("River", "RiverSign", (40, 4, -249.6), (16, 3, 0.3), "남한강", rgb(40, 90, 150), face="Back", ppu=14)
    for i, x in enumerate(range(-460, 100, 40)):
        add("River", tree(f"RiverTree{i}", (x, 0, -244), 10, 1.6, 12, rgb(90, 160, 80)))
        avoid.append((x - 4, x + 4, -248, -240))
    # 공원 (농구장·철봉·침대 자리)
    flat("Park", "ParkGrass", -480, -360, -250, -160, 0, rgb(100, 175, 85), "Grass", thick=0.25)
    flat("Park", "Court", -470, -420, -245, -205, 0.25, rgb(70, 120, 170), "SmoothPlastic", thick=0.1)
    label("Park", "ParkSign", (-420, 4, -159.6), (18, 3, 0.4), "갈산공원", rgb(60, 130, 60), face="Back", ppu=14)
    for i, (x, zz) in enumerate(((-370, -240), (-365, -175), (-470, -168))):
        add("Park", tree(f"ParkTree{i}", (x, 0, zz), 14, 2, 16, rgb(70, 150, 70)))
        avoid.append((x - 5, x + 5, zz - 5, zz + 5))

    parts = [folder(name, items) for name, items in groups.items()]
    return {
        "parts": parts,
        "avoid": avoid,
        "spots": {"hoop": (-445, -228), "bar": (-395, -230), "beds": (-400, -185)},
        "boss": (-420, -15),
        "rain": (-250, -10),
        "spawn": (-10, -25),
        "boards": [(-79, 10, -36), (-79, 10, -4)],
    }


WATER_COLOR = [90 / 255, 160 / 255, 220 / 255]
