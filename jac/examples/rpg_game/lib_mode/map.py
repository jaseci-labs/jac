from byllm.lib import Model, by
from dataclasses import dataclass


@dataclass
class Position:
    x: int
    y: int


@dataclass
class MapTiles:
    width: int
    height: int
    walls: list[Position]
    enemies: list[Position]
    player_pos: Position


def get_tilemap() -> list[str]:
    return _serialize_maptile(gen_tilemap())


@by(Model("gpt-4o"))
def gen_tilemap() -> MapTiles:  # type: ignore
    """Generate a tilemap for a game level, where all the edges should be walls
    there should only be *ONE* player and multiple enemies, all enemies should be placed
    randomly and the player should be able to reach all enemies. Make sure to place some
    walls inside the level and place the player near the center of the level. (w*h should be 20*15)
    """


def _serialize_maptile(maptile: MapTiles) -> list[str]:
    ret = [["."] * maptile.width for _ in range(maptile.height)]
    for wall in maptile.walls:
        ret[wall.y][wall.x] = "B"
    for enemy in maptile.enemies:
        ret[enemy.y][enemy.x] = "E"
    ret[maptile.player_pos.y][maptile.player_pos.x] = "P"
    return ["".join(row) for row in ret]


tilemap = [
    "BBBBBBBBBBBBBBBBBBBB",
    "B..E...............B",
    "B..................B",
    "B....BBBB......E...B",
    "B..................B",
    "B..................B",
    "B.........P........B",
    "B..................B",
    "B....E.............B",
    "B..................B",
    "B.......BBB........B",
    "B.........B........B",
    "B.........B....E...B",
    "B.........B........B",
    "BBBBBBBBBBBBBBBBBBBB",
]

tilemap_3 = [
    "BBBBBBBBBBBBBBBBBBBB",
    "B..........E.......B",
    "B..................B",
    "B.......BBBB.......B",
    "B......E...........B",
    "B..................B",
    "B...E..............B",
    "B..................B",
    "B..BBBBB...........B",
    "B.........E........B",
    "B..................B",
    "B............P.....B",
    "B..................B",
    "B.......E..........B",
    "BBBBBBBBBBBBBBBBBBBB",
]

tilemap_4 = [
    "BBBBBBBBBBBBBBBBBBB",
    "B........E........B",
    "B.BBBBBBB.BBBBBBB.B",
    "B.B..P..B.B.....B.B",
    "B.B.BBB.B.B.BBB.B.B",
    "B.B.B...B...B.B.B.B",
    "B.B.B.BBBBB.B.B.B.B",
    "B.B.B.......B.B.B.B",
    "B.B.B.BBB.BBB.B.B.B",
    "B.B...B...B...B.B.B",
    "B.BBB.BBB.BBB.BBB.B",
    "B...B...EEE......B.",
    "BBB.BBB.B.BBB.BBB.B",
    "B.....B...B.....B.B",
    "BBBBBBBBBBBBBBBBBBB",
]

tilemap_5 = [
    "BBBBBBBBBBBBBBBBBBBB",
    "B........E.........B",
    "B..BBBB............B",
    "B..B...............B",
    "B..B........E......B",
    "B..B...............B",
    "B..B.....BBBB......B",
    "B..B..........E....B",
    "B..B...............B",
    "B..B...............B",
    "B..B........P......B",
    "B..B...............B",
    "B..BBBB............B",
    "B.....E............B",
    "BBBBBBBBBBBBBBBBBBBB",
]

tilemap_6 = [
    "BBBBBBBBBBBBBBBBBBBB",
    "B.......E..........B",
    "BB.BB.BB.BB.BB.BB.BB",
    "B..B............B..B",
    "BB.B..BB.BB.BB.B..BB",
    "B.............E....B",
    "BBBB..BB.BB.BB.BB.BB",
    "B..B............B..B",
    "B.BBBBB.BB.BB.BB.BBB",
    "B.....E...........PB",
    "BB.BB.BB.BB.BB.BB.BB",
    "B..B............B..B",
    "BB.BB.BB.BB.BB.BB.BB",
    "B.............E....B",
    "BBBBBBBBBBBBBBBBBBBB",
]
