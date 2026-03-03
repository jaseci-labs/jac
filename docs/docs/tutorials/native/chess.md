# Build a Chess Engine

> **Prerequisites:** Familiarity with [Native Compilation](../../reference/language/native-pathway.md) basics -- `na {}` blocks, `.na.jac` files, and `with entry {}`.

In this tutorial you will explore a fully playable chess engine written in idiomatic Jac, run it on the native compilation pathway, and compile it to a standalone binary. Along the way you will learn:

- How **`jac run --autonative`** auto-promotes compatible `.jac` files to native execution
- How **`jac nacompile`** produces a standalone binary with no external toolchain
- How **`sys.argv`** enables command-line argument parsing in native programs
- How **declaration/implementation separation** keeps large native programs organized

The full source lives at [`jac/examples/chess/`](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/examples/chess):

- `chess.jac` -- declarations (types, signatures, entry point)
- `chess.impl.jac` -- all method implementations

---

## What You Will Build

An interactive terminal chess game with:

- A full 8x8 board with all standard pieces
- Legal move generation and validation
- Check, checkmate, and stalemate detection
- Castling, en passant, and pawn promotion
- Position evaluation with center-control and development bonuses
- A `--benchmark` mode that plays automated random games
- Command-line argument parsing via `sys.argv`

---

## Step 1: Run It

Before diving into the code, try running the chess engine. You have three options, each demonstrating a different part of the native pathway.

### Option A: Standard Jac Execution

```bash
jac run jac/examples/chess/chess.jac
```

This runs on the Python backend -- full compatibility, standard execution.

### Option B: Auto-Native Promotion

```bash
jac run --autonative jac/examples/chess/chess.jac
```

The `--autonative` flag tells the compiler to analyze the program and, if it only uses native-compatible features (no walkers, async, lambdas, PyPI imports, etc.), automatically promote it to native execution. The chess engine is fully native-compatible, so the compiler JIT-compiles it to machine code and runs it natively -- same `.jac` file, no changes needed.

!!! info "How auto-promotion works"
    The `NativeCompatCheckPass` walks the AST and verifies the program uses only native-supported constructs. If it passes, the compiler generates LLVM IR, JIT-compiles it, and executes natively. If it fails (e.g., the file uses walkers or `by llm()`), execution falls back to Python transparently.

### Option C: Standalone Binary

```bash
jac nacompile jac/examples/chess/chess.jac -o chess
./chess
```

This compiles the `.jac` file to a self-contained binary. No Python runtime, no external compiler, no external linker -- the entire toolchain runs within Jac itself. The output is a native executable you can distribute and run anywhere.

### Benchmark Mode

The chess engine accepts command-line arguments via `sys.argv`. Pass `--benchmark` (or `-b`) to run automated random games instead of interactive play:

```bash
# With autonative
jac run --autonative jac/examples/chess/chess.jac -- --benchmark

# With compiled binary
jac nacompile jac/examples/chess/chess.jac -o chess
./chess --benchmark
```

```
Running 10 games...

Game 1: Black wins
Game 2: White wins
Game 3: Draw
...

--- Results (10 games) ---
White wins: 4
Black wins: 3
Draws:      3
```

---

## Step 2: Project Structure

The chess engine uses Jac's **declaration/implementation separation** -- the same pattern as header files in C, but built into the language. This keeps the architecture scannable at a glance:

```
chess/
├── chess.jac          # Declarations: types, signatures, entry point
└── chess.impl.jac     # Implementations: all method bodies
```

The declaration file defines *what* exists. The implementation file defines *how* it works. The compiler links them together automatically.

---

## Step 3: Declarations (`chess.jac`)

### Enums and Constants

The declaration file starts with enums and global constants:

```jac
enum Color { WHITE = 0, BLACK = 1 }
enum PieceKind { PAWN = 0, KNIGHT = 1, BISHOP = 2, ROOK = 3, QUEEN = 4, KING = 5 }

# Castling rights as bit flags
glob CASTLE_WK: int = 0x01,
     CASTLE_WQ: int = 0x02,
     CASTLE_BK: int = 0x04,
     CASTLE_BQ: int = 0x08,
     CASTLE_ALL: int = 0x0F;

glob CENTER_MASK: int = 0b00111100;  # Bitmask for center files
glob BOARD_SIZE: int = 8;
```

Global dictionaries map piece kinds to display symbols and material values:

```jac
glob WHITE_SYMBOLS: dict[PieceKind, str] = {
    PieceKind.PAWN: "P", PieceKind.KNIGHT: "N", PieceKind.BISHOP: "B",
    PieceKind.ROOK: "R", PieceKind.QUEEN: "Q", PieceKind.KING: "K"
};

glob PIECE_VALUES: dict[PieceKind, int] = {
    PieceKind.PAWN: 100, PieceKind.KNIGHT: 320, PieceKind.BISHOP: 330,
    PieceKind.ROOK: 500, PieceKind.QUEEN: 900, PieceKind.KING: 20000
};
```

**Native features:** enums, global variables, hex/binary literals, dict literals with enum keys.

### Forward Declarations and Function Signatures

Forward declarations let types reference each other before they are fully defined:

```jac
obj Board;
obj Piece;

def opposite_color(color: Color) -> Color;
def to_algebraic(pos: tuple[int, int]) -> str;
def create_piece(kind: PieceKind, color: Color, row: int, col: int) -> Piece;
```

### The Piece Hierarchy

The type hierarchy is declared with clean signatures -- no method bodies:

```jac
obj Piece {
    has color: Color,
        kind: PieceKind,
        pos: tuple[int, int],
        has_moved: bool = False;

    def row -> int;
    def col -> int;
    def set_pos(row: int, col: int) -> None;
    def symbol -> str;
    def raw_moves(board: Board) -> list[Move];
    def slide_moves(board: Board, directions: list[tuple[int, int]]) -> list[Move];
}

obj Pawn(Piece)   { override def raw_moves(board: Board) -> list[Move]; }
obj Knight(Piece) { override def raw_moves(board: Board) -> list[Move]; }
obj Bishop(Piece) { override def raw_moves(board: Board) -> list[Move]; }
obj Rook(Piece)   { override def raw_moves(board: Board) -> list[Move]; }
obj Queen(Piece)  { override def raw_moves(board: Board) -> list[Move]; }
obj King(Piece)   { override def raw_moves(board: Board) -> list[Move]; }
```

Each subclass uses `override` to declare that it replaces the base `raw_moves()`. The compiler generates vtables so the correct implementation is called based on the object's actual type at runtime.

**Native features:** single inheritance, virtual dispatch via vtables, forward declarations, union types (`Piece | None`), tuples.

### The Entry Point with `sys.argv`

The entry point parses command-line arguments to choose between interactive play and benchmark mode:

```jac
import sys;

glob game = Game();

with entry {
    _benchmark_mode: int = 0;
    _args = sys.argv;
    for i in range(1, len(_args)) {
        arg = _args[i];
        if arg == "--benchmark" or arg == "-b" {
            _benchmark_mode = 10;
        }
    }
    if _benchmark_mode > 0 {
        game.benchmark(_benchmark_mode);
    } else {
        game.play();
    }
}
```

`sys.argv` is a `list[str]` where `argv[0]` is the program/binary name. This works identically whether you run with `jac run --autonative` or as a compiled binary.

**Native features:** `import sys`, `sys.argv`, command-line argument parsing, string comparison.

---

## Step 4: Implementations (`chess.impl.jac`)

All method bodies live in the `impl` file. A few highlights:

### Sliding Piece Movement

The base `Piece` provides a `slide_moves()` method used by Bishop, Rook, and Queen:

```jac
impl Piece.slide_moves(board: Board, directions: list[tuple[int, int]]) -> list[Move] {
    moves: list[Move] = [];
    for d in directions {
        (dr, dc) = d;                    # Tuple unpacking
        r = self.row() + dr;
        c = self.col() + dc;
        while board.valid_pos(r, c) {
            target: Piece | None = board.at(r, c);
            if target is None {
                moves.append(Move(from_pos=self.pos, to_pos=(r, c)));
            } elif target.color != self.color {
                moves.append(Move(from_pos=self.pos, to_pos=(r, c)));
                break;
            } else {
                break;
            }
            r += dr;
            c += dc;
        }
    }
    return moves;
}
```

Each sliding piece just passes its directions:

```jac
impl Bishop.raw_moves(board: Board) -> list[Move] {
    return self.slide_moves(board, [(-1, -1), (-1, 1), (1, -1), (1, 1)]);
}

impl Rook.raw_moves(board: Board) -> list[Move] {
    return self.slide_moves(board, [(-1, 0), (1, 0), (0, -1), (0, 1)]);
}
```

### King Move Generation with Comprehensions

The King uses a list comprehension with nested loops and a filter:

```jac
impl King.raw_moves(board: Board) -> list[Move] {
    moves: list[Move] = [];
    row = self.row();
    col = self.col();

    adjacent: list[tuple[int, int]] = [
        (row + dr, col + dc)
        for dr in [-1, 0, 1]
        for dc in [-1, 0, 1]
        if not (dr == 0 and dc == 0)
    ];

    for pos in adjacent {
        (r, c) = pos;
        if board.valid_pos(r, c) {
            target: Piece | None = board.at(r, c);
            if target is None or target.color != self.color {
                moves.append(Move(from_pos=self.pos, to_pos=pos));
            }
        }
    }
    return moves;
}
```

### Board Initialization with `postinit`

The board uses nested list comprehensions and a `postinit` hook:

```jac
impl Board.postinit {
    self.squares = [[None for _ in range(BOARD_SIZE)] for _ in range(BOARD_SIZE)];
    self.setup_pieces();
}
```

### Set Operations for Attack Detection

Attacked squares are computed using set comprehensions and set union:

```jac
impl Board.attacked_squares(by_color: Color) -> set[tuple[int, int]] {
    attacked: set[tuple[int, int]] = set();
    for piece in self.pieces_of(by_color) {
        attacked |= {m.to_pos for m in piece.raw_moves(self)};
    }
    return attacked;
}
```

### Bitwise Operations for Castling

Castling rights use bitwise flags -- AND, OR, NOT:

<!-- jac-skip -->
```jac
# King moved -- remove both castling rights for that side
if piece.kind == PieceKind.KING {
    if piece.color == Color.WHITE {
        self.castling_rights &= ~(CASTLE_WK | CASTLE_WQ);
    } else {
        self.castling_rights &= ~(CASTLE_BK | CASTLE_BQ);
    }
}
```

### Position Evaluation

The evaluator uses material values, center-control bonuses, and development bonuses:

```jac
impl Board.evaluate(color: Color) -> int {
    score = 0;
    for r in range(BOARD_SIZE) {
        for c in range(BOARD_SIZE) {
            piece: Piece | None = self.squares[r][c];
            if piece is not None {
                base = PIECE_VALUES[piece.kind];
                center_bonus = 0;
                if (1 << c & CENTER_MASK) != 0 and 2 <= r and r <= 5 {
                    center_bonus = base // 10;
                }
                dev_bonus = 8 if piece.has_moved and piece.kind != PieceKind.KING else 0;
                total = base + center_bonus + dev_bonus;
                if piece.color == color {
                    score += total;
                } else {
                    score -= total;
                }
            }
        }
    }
    return score;
}
```

### Benchmark Mode

The `benchmark` method runs N automated games and reports results:

```jac
impl Game.benchmark(num_games: int) -> None {
    white_wins = 0;
    black_wins = 0;
    draws = 0;

    print(f"Running {num_games} games...\n");

    for i in range(num_games) {
        g = Game();
        seed_random(i * 7919 + 42);
        result = g.play_auto();

        if result == "White" { white_wins += 1; }
        elif result == "Black" { black_wins += 1; }
        else { draws += 1; }

        print(f"Game {i + 1}: {result} wins" if result != "Draw" else f"Game {i + 1}: Draw");
    }

    print(f"\n--- Results ({num_games} games) ---");
    print(f"White wins: {white_wins}");
    print(f"Black wins: {black_wins}");
    print(f"Draws:      {draws}");
}
```

---

## Step 5: Three Ways to Run

This chess engine demonstrates an important property of Jac's native pathway: **the same `.jac` source file works across all three execution modes**.

### 1. Python Backend (default)

```bash
jac run jac/examples/chess/chess.jac
```

Uses the standard Python runtime. Full compatibility, familiar debugging tools.

### 2. Auto-Native (`--autonative`)

```bash
jac run --autonative jac/examples/chess/chess.jac -- --benchmark
```

The compiler analyzes the program at build time. If all code is native-compatible, it JIT-compiles to machine code and runs natively. If not, it falls back to Python. No code changes required -- the same `.jac` file works either way.

This is ideal during development: write normal Jac, add `--autonative` when you want native speed.

### 3. Standalone Binary (`nacompile`)

```bash
jac nacompile jac/examples/chess/chess.jac -o chess
./chess --benchmark
```

Produces a self-contained executable. No Python needed at runtime, no external compiler or linker in the build process. The binary includes everything from the LLVM-compiled machine code to the final ELF/Mach-O packaging.

---

## Feature Recap

This program exercises a wide range of native Jac features:

| Feature | Where Used |
|---------|-----------|
| Declaration/impl separation | `chess.jac` / `chess.impl.jac` |
| Enums | `Color`, `PieceKind` |
| Global variables and dicts | `PIECE_VALUES`, `WHITE_SYMBOLS`, castling flags |
| Hex/binary literals | `0x01`, `0b00111100` |
| Objects with fields and methods | `Move`, `Piece`, `Board`, `Game` |
| Single inheritance + vtables | `Pawn(Piece)`, `Knight(Piece)`, etc. |
| Forward declarations | `obj Board;` before `Piece` references it |
| Tuples and unpacking | `(row, col) = pos;` |
| Lists and nested lists | `squares: list[list[Piece \| None]]` |
| List comprehensions | Legal move filtering, adjacent squares |
| Dict comprehensions | `piece_map()` position lookup |
| Set comprehensions and `\|=` | `attacked_squares()` |
| Union types | `Piece \| None` |
| Ternary expressions | `direction = -1 if WHITE else 1` |
| Bitwise operations | Castling rights: `&`, `\|`, `~`, `<<` |
| Augmented assignment | `+=`, `-=`, `&=`, `\|=` |
| F-strings | Board display, move notation |
| String methods | `strip()`, `split()`, `ord()`, `chr()` |
| `postinit` hook | Board and Game initialization |
| `import sys` / `sys.argv` | `--benchmark` flag parsing |
| `input()` | Interactive move entry |

---

## Next Steps

- Add a minimax AI opponent using the existing `evaluate()` method
- Try the benchmark with `./chess --benchmark` and compare Python vs native speed
- Explore [C Library Interop](../../reference/language/native-pathway.md#c-library-interop) to add a graphical interface using a library like raylib
- Read the full source: [`chess.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/examples/chess/chess.jac) and [`chess.impl.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/examples/chess/chess.impl.jac)
