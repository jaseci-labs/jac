impl LevelManager.get_next_level{
    # Keeping Only the Last 3 Levels
    if len(self.prev_levels) > 3 {
        self.prev_levels.pop(0);
        self.prev_level_maps.pop(0);
    }
    # Generating the New Level
    new_level = self.create_next_level(self.prev_levels, self.current_difficulty);
    self.prev_levels.append(new_level);
    # Using the llm to fill un the attributes of Map_tiles object instance
    new_level_map = self.create_next_map(new_level);
    self.prev_level_maps.append(new_level_map);
    # Increasing the Difficulty for end of every 2 Levels
    if self.current_level % 2 == 0 {
        self.current_difficulty += 1;
    }
    new_map = self.get_map(new_level_map);
    return new_map;
}

impl LevelManager.get_map{
    map_tiles: list[list[str]] = [
        ['.' for _ in range(map.level.width)] for _ in range(map.level.height)
    ];
    for wall in map.walls {
        for x in range(wall.start_pos.x, wall.end_pos.x + 1) {
            for y in range(wall.start_pos.y, wall.end_pos.y + 1) {
                map_tiles[y][x] = 'B';
            }
        }
    }
    for obs in map.small_obstacles {
        map_tiles[obs.y][obs.x] = 'B';
    }
    for enemy in map.enemies {
        map_tiles[enemy.y][enemy.x] = 'E';
    }
    map_tiles[map.player_pos.y][map.player_pos.x] = 'P';
    map_tiles: list[list[str]] = [['B'] + row + ['B'] for row in map_tiles];
    map_tiles: list[list[str]] = [['B' for _ in range(map.level.width + 2)]] + map_tiles + [
        ['B' for _ in range(map.level.width + 2)]
    ];
    return [''.join(row) for row in map_tiles];
}
