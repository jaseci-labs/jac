# RPG Level Generator: AI-Powered Game Design

Build a dynamic RPG level generator using LLMs and Jac's `by llm` syntax.

**Time:** 30 minutes
**Level:** Advanced

---

## What You'll Build

An AI-powered system that:

- Generates balanced, progressively challenging game levels
- Creates detailed maps with walls, enemies, and obstacles
- Scales difficulty automatically as players progress
- Produces playable ASCII map visualizations

---

## Why This Example?

This example showcases:

| Concept | How It's Used |
|---------|---------------|
| **byLLM** | AI generates level configurations and maps |
| **Structured Types** | Objects guide AI understanding |
| **Progressive Systems** | Difficulty curves and variety |
| **Practical Output** | AI data becomes usable game content |

---

## Prerequisites

```bash
pip install byllm
export OPENAI_API_KEY="your-key"
```

---

## Data Structures

The key to AI-powered generation is well-defined types. The LLM understands these structures and generates appropriate values.

### Position and Walls

```jac
obj Position {
    has x: int;
    has y: int;
}

obj Wall {
    has start_pos: Position;
    has end_pos: Position;
}
```

### Level Configuration

```jac
obj Level {
    has name: str;
    has difficulty: int;
    has width: int;
    has height: int;
    has num_wall: int;
    has num_enemies: int;
    has time_countdown: int;
    has n_retries_allowed: int;
}
```

### Map Layout

```jac
obj Map {
    has level: Level;
    has walls: list[Wall];
    has small_obstacles: list[Position];
    has enemies: list[Position];
    has player_pos: Position;
}
```

---

## AI-Powered Generation

The magic happens with `by llm()`:

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o", verbose=True);

obj LevelManager {
    has current_level: int = 0;
    has current_difficulty: int = 1;
    has prev_levels: list[Level] = [];
    has prev_level_maps: list[Map] = [];

    """Generate a new level configuration based on difficulty and history."""
    def create_next_level(
        last_levels: list[Level],
        difficulty: int,
        level_width: int,
        level_height: int
    ) -> Level by llm();

    """Generate a detailed map for a given level."""
    def create_next_map(level: Level) -> Map by llm();
}
```

**Key insight:** The AI automatically understands:

- Previous levels (to ensure variety)
- Difficulty scaling
- Spatial constraints (width, height)
- Object relationships (Map contains Level)

---

## Level Flow Management

```jac
def get_next_level() -> tuple[Level, Map] {
    self.current_level += 1;

    # Keep only last 3 levels for context
    if len(self.prev_levels) > 3 {
        self.prev_levels.pop(0);
        self.prev_level_maps.pop(0);
    }

    # AI generates the level
    new_level = self.create_next_level(
        self.prev_levels,
        self.current_difficulty,
        20, 20  # 20x20 grid
    );
    self.prev_levels.append(new_level);

    # AI generates the map
    new_level_map = self.create_next_map(new_level);
    self.prev_level_maps.append(new_level_map);

    # Increase difficulty every 2 levels
    if self.current_level % 2 == 0 {
        self.current_difficulty += 1;
    }

    return (new_level, new_level_map);
}
```

---

## Map Visualization

Convert AI-generated maps to ASCII:

```jac
def get_map(map: Map) -> list[str] {
    # Initialize empty grid
    tiles = [['.' for _ in range(map.level.width)]
             for _ in range(map.level.height)];

    # Place walls
    for wall in map.walls {
        for x in range(wall.start_pos.x, wall.end_pos.x + 1) {
            for y in range(wall.start_pos.y, wall.end_pos.y + 1) {
                tiles[y-1][x-1] = 'B';
            }
        }
    }

    # Place obstacles
    for obs in map.small_obstacles {
        tiles[obs.y-1][obs.x-1] = 'B';
    }

    # Place enemies
    for enemy in map.enemies {
        tiles[enemy.y-1][enemy.x-1] = 'E';
    }

    # Place player
    tiles[map.player_pos.y-1][map.player_pos.x-1] = 'P';

    # Add borders
    tiles = [['B'] + row + ['B'] for row in tiles];
    border = ['B' for _ in range(map.level.width + 2)];
    tiles = [border] + tiles + [border];

    return [''.join(row) for row in tiles];
}
```

**Symbols:**

- `.` = Empty space
- `B` = Block/Wall
- `E` = Enemy
- `P` = Player start

---

## Testing the Generator

```jac
# test_generator.jac
import from level_manager { LevelManager }

with entry {
    manager = LevelManager();

    print("Generating 3 AI-powered levels...\n");

    for i in range(3) {
        (level, map_obj) = manager.get_next_level();
        visual_map = manager.get_map(map_obj);

        print(f"=== LEVEL {i+1} ===");
        print(f"Difficulty: {level.difficulty}");
        print(f"Enemies: {level.num_enemies}");
        print(f"Walls: {level.num_wall}");
        print("Map:");
        for row in visual_map {
            print(row);
        }
        print("\n");
    }
}
```

Run it:

```bash
jac test_generator.jac
```

---

## Sample Output

```
=== LEVEL 1 ===
Difficulty: 1
Enemies: 2
Walls: 3
Map:
BBBBBBBBBBBBBBBBBBBBBB
B....................B
B.....B..............B
B....................B
B........E...........B
B....................B
B..........P.........B
B....................B
B.E..................B
B....................B
BBBBBBBBBBBBBBBBBBBBBB
```

Each run produces different layouts as the AI creates unique levels.

---

## How It Works

1. **Structured Types** - `Level` and `Map` objects define what the AI generates
2. **Historical Context** - Previous levels prevent repetition
3. **Difficulty Scaling** - Increases every 2 levels
4. **Spatial Constraints** - Width/height guide placement
5. **AI Creativity** - LLM handles the actual creative work

---

## Extension Ideas

1. **More object types** - Treasure, power-ups, keys, doors
2. **Different terrain** - Water, lava, grass tiles
3. **Boss levels** - Special every 5th level
4. **Player stats** - Health, damage, speed progression
5. **Theme variations** - Dungeon, forest, castle themes

---

## Full Source Code

- [RPG Game Source](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm/examples/mtp_examples/rpg_game)
- [Fantasy Trading Game](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm/examples/mtp_examples/fantasy_trading_game) - Similar patterns

---

## Key Takeaways

1. **Types guide AI** - Well-defined objects lead to better generation
2. **`by llm` is declarative** - Describe what you want, not how
3. **Context matters** - Pass history and constraints for variety
4. **Practical output** - Convert AI data to usable formats

---

## Next Examples

- [EmailBuddy](emailbuddy.md) - AI-powered email assistant
- [LittleX](littlex.md) - Social media platform
