# <span style="color: orange">Tutorial: Building an AI-Powered RPG Level Generator

This tutorial demonstrates how to build a dynamic RPG game level generator using Large Language Models (LLMs) and Jaclang's `by llm` syntax. The tutorial covers creating a system that uses AI to generate balanced, progressively challenging game levels.

<div align="center">
  <video width="480" height="300" autoplay loop muted playsinline>
    <source src="/learn/examples/mtp_examples/assets/rpg_demo.mp4" type="video/mp4">
    Your browser does not support the video tag.
  </video>
</div>

## <span style="color: orange">Overview

This tutorial covers building an AI-driven RPG level generator using Jaclang's `by llm` syntax. The system creates game levels automatically through structured data types for spatial positioning and game elements, progressive difficulty scaling that adapts to player progress, and dynamic map rendering from AI-generated data.

## <span style="color: orange">Prerequisites

Required dependencies:

```bash
pip install mtllm
```

OpenAI API key configuration:
```bash
export OPENAI_API_KEY="your-api-key-here"
```

- Basic knowledge of [Jaclang syntax](/jac_book/)
- Familiarity with game development concepts (optional)

## <span style="color: orange">Implementation Steps

The implementation consists of the following components:

1. **Define Game Data Structures** - Create the building blocks for the game world
2. **Implement AI-Powered Methods** - Use `by llm` to delegate level creation to AI
3. **Build the Level Manager** - Coordinate the generation process
4. **Create Map Conversion Logic** - Transform AI output into playable levels
5. **Test and Iterate** - Run the system and validate AI-generated levels

## <span style="color: orange">Step 1: Define Game Data Structures

The first step involves creating the fundamental data types that represent the game world. These structures serve as a vocabulary that the AI uses to understand and generate game content.

### <span style="color: orange">Basic Position and Wall Objects

Create a new file called `level_manager.jac` and add these basic structures:

```jac linenums="1"
obj Position {
    has x: int, y: int;
}

obj Wall {
    has start_pos: Position, end_pos: Position;
}
```

**Implementation details:**
- `Position` represents any point in 2D space with x, y coordinates
- `Wall` defines a barrier using start and end positions

### <span style="color: orange">Game Configuration Objects

Add the main game configuration objects:

```jac linenums="1"
obj Level {
    has name: str, difficulty: int;
    has width: int, height: int, num_wall: int, num_enemies: int;
    has time_countdown: int, n_retries_allowed: int;
}

obj Map {
    has level: Level, walls: list[Wall], small_obstacles: list[Position];
    has enemies: list[Position];
    has player_pos: Position;
}
```

**Structure functions:**
- `Level` defines the game rules (difficulty, time limits, constraints)
- `Map` contains the actual layout (where everything is positioned)
- The AI uses these types to understand what constitutes a valid, balanced level

## <span style="color: orange">Step 2: Implement AI-Powered Generation Methods

This step creates the core AI methods that generate game content. First, import and configure the AI model, then add the `LevelManager` object:

```jac linenums="1"
import from mtllm { Model }

glob llm = Model(model_name="gpt-4o", verbose=True);

obj LevelManager {
    has current_level: int = 0, current_difficulty: int = 1,
        prev_levels: list[Level] = [], prev_level_maps: list[Map] = [];

    def create_next_level (last_levels: list[Level], difficulty: int, level_width: int, level_height: int)
    -> Level by llm();

    def create_next_map(level: Level) -> Map by llm();
}
```

**AI configuration:**
- Import the `Model` class from the `mtllm` module
- The global `llm` variable configures the AI model (GPT-4o in this case)
- `verbose=True` enables detailed output during generation

### <span style="color: orange">AI Method Implementation

The `by llm` methods work as follows:

**Level Creation Method**
```jac
def create_next_level (last_levels: list[Level], difficulty: int, level_width: int, level_height: int)
-> Level by llm();
```

**Method parameters:**
- **Historical Context**: `last_levels` - Previous levels for ensuring variety
- **Difficulty Guidance**: `difficulty` - Scale the challenge appropriately
- **Spatial Constraints**: `level_width, level_height` - Boundary parameters
- **Expected Output**: Return a complete `Level` object

**Map Generation Method**
```jac
def create_next_map(level: Level) -> Map by llm();
```

**Method function:**

- Takes a high-level `Level` configuration
- Generates specific positions for walls, enemies, and the player
- Creates a balanced, playable layout
- Returns a detailed `Map` object

??? note "AI Data Structure Understanding"
    The AI automatically understands data structures. When you pass a `Level` object, the AI knows about all its properties (difficulty, dimensions, enemy count, etc.) and uses this context to make intelligent decisions.

## <span style="color: orange">Step 3: Build the Level Generation Logic

Implement the coordination logic that manages the AI generation process. Add this method to the `LevelManager`:

```jac
def get_next_level -> tuple(Level, Map) {
    self.current_level += 1;

    # Keeping Only the Last 3 Levels
    if len(self.prev_levels) > 3 {
        self.prev_levels.pop(0);
        self.prev_level_maps.pop(0);
    }

    # Generating the New Level
    new_level = self.create_next_level(
        self.prev_levels,
        self.current_difficulty,
        20, 20
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
```

### <span style="color: orange">Generation Flow

The `get_next_level()` method executes the following sequence:

1. **Level Counter**: Increments the current level number
2. **Memory Management**: Keeps only the last 3 levels to provide recent context without overwhelming the AI
3. **AI Level Generation**: Calls the AI to create a new level configuration
4. **AI Map Generation**: Requests the AI to create specific positioning for the level
5. **Difficulty Progression**: Increases difficulty every 2 levels for natural progression
6. **Return Results**: Provides both the level config and detailed map

## <span style="color: orange">Step 4: Convert AI Output to Game Format

The AI generates structured data that must be converted to a visual representation. Create a function that converts the AI-generated `Map` into game tiles:

```jac
def get_map(map: Map) -> str {
    map_tiles = [['.' for _ in range(map.level.width)] for _ in range(map.level.height)];

    # Place walls
    for wall in map.walls {
        for x in range(wall.start_pos.x, wall.end_pos.x + 1) {
            for y in range(wall.start_pos.y, wall.end_pos.y + 1) {
                map_tiles[y-1][x-1] = 'B';
            }
        }
    }

    # Place obstacles, enemies, and player
    for obs in map.small_obstacles {
        map_tiles[obs.y-1][obs.x-1] = 'B';
    }
    for enemy in map.enemies {
        map_tiles[enemy.y-1][enemy.x-1] = 'E';
    }
    map_tiles[map.player_pos.y-1][map.player_pos.x-1] = 'P';

    # Add border walls
    map_tiles = [['B'] + row + ['B'] for row in map_tiles];
    map_tiles = [['B' for _ in range(map.level.width + 2)]] + map_tiles + [['B' for _ in range(map.level.width + 2)]];
    return [''.join(row) for row in map_tiles];
}
```

### <span style="color: orange">Map Conversion Process

The conversion function executes these operations:

1. **Initialize Grid**: Creates a 2D array filled with '.' (empty space)
2. **Place Walls**: Converts `Wall` objects into 'B' (block) characters
3. **Add Obstacles**: Places small obstacles as additional 'B' characters
4. **Position Enemies**: Places 'E' characters at enemy positions
5. **Place Player**: Sets 'P' character at the player's starting position
6. **Add Borders**: Surrounds the entire map with walls for boundaries

**Game Symbols:**

- `.` = Empty space (walkable)
- `B` = Block/Wall (impassable)
- `E` = Enemy (dangerous)
- `P` = Player (starting position)

## <span style="color: orange">Step 5: Test the AI Level Generator

Create a test file to validate the AI functionality. Create a new file called `test_generator.jac`:

```jac
import from level_manager { LevelManager }

with entry {
    level_manager = LevelManager();

    print("Generating 3 AI-powered levels...\n");

    for i in range(3) {
        level, map_obj = level_manager.get_next_level();
        visual_map = level_manager.get_map(map_obj);

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

### <span style="color: orange">Running the Generator

Execute the test with:
```bash
jac run test_generator.jac
```

Expected output:
```
=== LEVEL 1 ===
Difficulty: 1
Enemies: 2
Walls: 3
Map:
BBBBBBBBBBBBBBBBBBBBBB
B..................B
B.....B............B
B..................B
B........E.........B
B..................B
B..........P.......B
B..................B
B.E................B
BBBBBBBBBBBBBBBBBBBBBB
```

## <span style="color: orange">Summary

This tutorial demonstrates building an AI-powered RPG level generator that implements:

- **AI Integration**: Using `by llm` syntax to delegate complex generation tasks
- **Structured Data Design**: Creating types that guide AI understanding
- **Progressive Systems**: Building difficulty curves and variety mechanisms
- **Practical Application**: Converting AI output into usable game content

The approach combines structured programming with AI creativity. The developer provides the framework and constraints, while the AI handles the creative details.

For more details access the [full documentation of MTP](/learn/jac-mtllm/).