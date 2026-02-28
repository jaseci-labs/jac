"""A clean, idiomatic chess engine in Jac.

Demonstrates declaration/implementation separation, enums, obj inheritance,
comprehensions, bitwise operations, and the Jac type system.
"""

# ────────────────────── Enums ──────────────────────
"""Side to move."""
enum Color {
    WHITE = 0,
    BLACK = 1
}

"""Chess piece types."""
enum PieceKind {
    PAWN = 0,
    KNIGHT = 1,
    BISHOP = 2,
    ROOK = 3,
    QUEEN = 4,
    KING = 5
}

# ────────────────────── Constants ──────────────────────
glob BOARD_SIZE: int = 8;

# Castling rights as bit flags
glob CASTLE_WK: int = 0x01,
     CASTLE_WQ: int = 0x02,
     CASTLE_BK: int = 0x04,
     CASTLE_BQ: int = 0x08,
     CASTLE_ALL: int = 0x0F;

# Bitmask for center files (c through f)
glob CENTER_MASK: int = 0b00111100;

# Piece display symbols per side
glob WHITE_SYMBOLS: dict[PieceKind, str] = {
         PieceKind.PAWN: "P",
         PieceKind.KNIGHT: "N",
         PieceKind.BISHOP: "B",
         PieceKind.ROOK: "R",
         PieceKind.QUEEN: "Q",
         PieceKind.KING: "K"
     };

glob BLACK_SYMBOLS: dict[PieceKind, str] = {
         PieceKind.PAWN: "p",
         PieceKind.KNIGHT: "n",
         PieceKind.BISHOP: "b",
         PieceKind.ROOK: "r",
         PieceKind.QUEEN: "q",
         PieceKind.KING: "k"
     };

glob COL_NAMES: str = "abcdefgh";

# Material values (centipawns)
glob PIECE_VALUES: dict[PieceKind, int] = {
         PieceKind.PAWN: 100,
         PieceKind.KNIGHT: 320,
         PieceKind.BISHOP: 330,
         PieceKind.ROOK: 500,
         PieceKind.QUEEN: 900,
         PieceKind.KING: 20000
     };

# Simple LCG random state
glob _rand_state: int = 12345;

# ────────────────────── Forward declarations ──────────────────────
obj Board;
obj Piece;

# ────────────────────── Free functions ──────────────────────
"""Return the opposite color."""
def opposite_color(color: Color) -> Color;

"""Convert (row, col) to algebraic notation like 'e4'."""
def to_algebraic(pos: tuple[int, int]) -> str;

"""Create the right Piece subtype for a given kind."""
def create_piece(kind: PieceKind, color: Color, row: int, col: int) -> Piece;

"""Seed the built-in LCG random generator."""
def seed_random(seed: int) -> None;

"""Return a pseudo-random int in [0, max_val)."""
def random_int(max_val: int) -> int;

# ────────────────────── Move ──────────────────────
"""A chess move with enough state to undo it."""
obj Move {
    has from_pos: tuple[int, int],
        to_pos: tuple[int, int],
        is_castling: bool = False,
        is_en_passant: bool = False,
        is_promotion: bool = False,
        is_double_push: bool = False,
        rook_from_col: int = -1,
        rook_to_col: int = -1,
        captured_piece: Piece | None = None,
        promoted_from: Piece | None = None,
        prev_has_moved: bool = False,
        prev_ep_pos: tuple[int, int] = (-1, -1),
        prev_castling_rights: int = CASTLE_ALL;

    def from_row -> int;
    def from_col -> int;
    def to_row -> int;
    def to_col -> int;
}

# ────────────────────── Pieces ──────────────────────
"""Base piece — holds position, color, kind, and move generation."""
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

"""Pawn — forward movement, captures, en passant, promotion."""
obj Pawn(Piece) {
    override def raw_moves(board: Board) -> list[Move];
}

"""Knight — L-shaped jumps."""
obj Knight(Piece) {
    override def raw_moves(board: Board) -> list[Move];
}

"""Bishop — diagonal slider."""
obj Bishop(Piece) {
    override def raw_moves(board: Board) -> list[Move];
}

"""Rook — orthogonal slider."""
obj Rook(Piece) {
    override def raw_moves(board: Board) -> list[Move];
}

"""Queen — slides in all 8 directions."""
obj Queen(Piece) {
    override def raw_moves(board: Board) -> list[Move];
}

"""King — one square in any direction."""
obj King(Piece) {
    override def raw_moves(board: Board) -> list[Move];
}

# ────────────────────── Board ──────────────────────
"""8x8 board that owns the squares and handles make/undo."""
obj Board {
    has squares: list[list[Piece | None]] = [],
        ep_pos: tuple[int, int] = (-1, -1),
        castling_rights: int = CASTLE_ALL;

    def postinit;
    def setup_pieces -> None;
    def valid_pos(row: int, col: int) -> bool;
    def at(row: int, col: int) -> Piece | None;
    def put(row: int, col: int, piece: Piece | None) -> None;
    def pieces_of(color: Color) -> list[Piece];
    def piece_map(color: Color) -> dict[tuple[int, int], Piece];
    def attacked_squares(by_color: Color) -> set[tuple[int, int]];
    def make_move(move: Move) -> None;
    def undo_move(move: Move) -> None;
    def evaluate(color: Color) -> int;
    def display -> None;
    def fen_placement -> str;
}

# ────────────────────── Game ──────────────────────
"""Top-level game controller: legality checking, turn management, I/O loop."""
obj Game {
    has board: Board | None = None,
        current_turn: Color = Color.WHITE,
        is_over: bool = False,
        move_count: int = 0;

    def postinit;
    def find_king(color: Color) -> Piece | None;
    def square_attacked(row: int, col: int, by_color: Color) -> bool;
    def in_check(color: Color) -> bool;
    def legal_moves(color: Color) -> list[Move];
    def is_checkmate(color: Color) -> bool;
    def is_stalemate(color: Color) -> bool;
    def parse_input(text: str) -> tuple[int, int, int, int] | None;
    def move_summary -> str;
    def play -> None;
    def play_auto -> str;
    def benchmark(num_games: int) -> None;
}

# ────────────────────── Entry ──────────────────────
# Set _benchmark_mode > 0 to run that many automated games.
glob _benchmark_mode: int = 0,
     game = Game();

with entry {
    if _benchmark_mode > 0 {
        game.benchmark(_benchmark_mode);
    } else {
        game.play();
    }
}
