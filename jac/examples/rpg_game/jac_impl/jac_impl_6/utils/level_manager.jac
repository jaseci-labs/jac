import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o", verbose=True);

obj Position {
    has x: int,
        y: int;
}

obj Wall {
    has start_pos: Position,
        end_pos: Position;
}

obj Map_tiles {
    has level: Level,
        walls: list[Wall],
        small_obstacles: list[Position],
        enemies: list[Position],
        player_pos: Position;
}

obj Level {
    has name: int,
        difficulty: int,
        time: int,
        width: int,
        height: int,
        num_wall: int,
        num_enemies: int;
}

obj LevelManager {
    has current_level: int = 0,
        current_difficulty: int = 1,
        prev_levels: list[Level] = [],
        prev_level_maps: list[Map_tiles] = [];

    def create_next_level(last_levels: list[Level], difficulty: int) -> Level by llm(
        temperature=0.8
    );

    def create_next_map(level: Level) -> Map_tiles by llm(temperature=0.8);
    '''Get the Next Level'''
    def get_next_level(current_level: int) -> tuple(Level, Map_tiles);

    '''Get the map of the level'''
    def get_map(map: Map_tiles) -> str;
}
