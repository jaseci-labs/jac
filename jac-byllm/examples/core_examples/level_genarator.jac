import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o");

obj Position {
    has x: int,
        y: int;
}

obj Wall {
    has start_pos: Position,
        end_pos: Position;
}

obj Map {
    has level: Level,
        walls: list[Wall],
        small_obstacles: list[Position],
        enemies: list[Position],
        player_pos: Position;
}

obj Level {
    has name: str,
        difficulty: int,
        width: int,
        height: int,
        num_wall: int,
        num_enemies: int,
        time_countdown: int,
        n_retries_allowed: int;
}

obj LevelManager {
    has current_level: int = 0,
        current_difficulty: int = 1,
        prev_levels: list[Level] = [],
        prev_level_maps: list[Map] = [];

    def create_next_level(
        last_levels: list[Level], difficulty: int, level_width: int, level_height: int
    ) -> Level by llm();

    def create_next_map(level: Level) -> Map by llm();
    def get_next_level -> tuple(Level, Map) {
        self.current_level += 1;
        # Keeping Only the Last 3 Levels
        if len(self.prev_levels) > 3 {
            self.prev_levels.pop(0);
            self.prev_level_maps.pop(0);
        }
        # Generating the New Level
        new_level = self.create_next_level(
            self.prev_levels, self.current_difficulty, 20, 20
        );

        self.prev_levels.append(new_level);
        # Generating the Map of the New Level
        new_level_map = self.create_next_map(new_level);
        self.prev_level_maps.append(new_level_map);
        # Increasing the Difficulty for end of every 2 Levels
        if self.current_level % 2 == 0 {
            self.current_difficulty += 1;
        }
        return (new_level, new_level_map);
    }
}

'''Get the map of the level'''
def get_map(map: Map) -> str {
    map_tiles = [
        ['.' for _ in range(map.level.width)] for _ in range(map.level.height)
    ];

    for wall in map.walls {
        for x in range(wall.start_pos.x, wall.end_pos.x + 1) {
            for y in range(wall.start_pos.y, wall.end_pos.y + 1) {
                map_tiles[y - 1][x - 1] = 'B';
            }
        }
    }

    for obs in map.small_obstacles {
        map_tiles[obs.y - 1][obs.x - 1] = 'B';
    }

    for enemy in map.enemies {
        map_tiles[enemy.y - 1][enemy.x - 1] = 'E';
    }
    map_tiles[map.player_pos.y - 1][map.player_pos.x - 1] = 'P';
    map_tiles = [['B'] + row + ['B'] for row in map_tiles];
    map_tiles = [['B' for _ in range(map.level.width + 2)]] + map_tiles + [
        ['B' for _ in range(map.level.width + 2)]
    ];
    return [''.join(row) for row in map_tiles];
}

glob level_manager = LevelManager();

with entry {
    for i in range(2) {
        (new_level, new_level_map) = level_manager.get_next_level();
        print(new_level);
        print('\n'.join(get_map(new_level_map)));
    }
}
