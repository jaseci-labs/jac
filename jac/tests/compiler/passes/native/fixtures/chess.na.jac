"""Chess game in Jac - native compilation reference implementation.

Uses obj inheritance with strict typing and no dynamic features.
Designed as the target spec for na {} codegen buildout.
"""

# ===================== Enums =====================
enum Color { WHITE = 0, BLACK = 1 }

enum PieceKind { PAWN = 0, KNIGHT = 1, BISHOP = 2, ROOK = 3, QUEEN = 4, KING = 5 }

# ===================== Constants using various literals =====================
# Bitwise flags for castling rights (using hex and binary literals)
glob CASTLE_WK: int = 0x01,  # White king-side   (binary: 0b0001)
     CASTLE_WQ: int = 0x02,  # White queen-side  (binary: 0b0010)
     CASTLE_BK: int = 0x04,  # Black king-side   (binary: 0b0100)
     CASTLE_BQ: int = 0x08;  # Black queen-side  (binary: 0b1000)

# Board dimension constants
glob BOARD_SIZE: int = 0o10,  # Octal 8
     CENTER_MASK: int = 0b00111100;  # Binary mask for center files

# Piece symbol mappings (dict values)
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

# Column names as string (bytes literal for reference: b"abcdefgh")
glob COL_NAMES: str = "abcdefgh";

# ===================== Forward Declarations =====================
obj Board;
obj Piece;

# ===================== Position as Tuple Helper =====================
def pos_to_tuple(row: int, col: int) -> tuple[int, int] {
    return (row, col);
}

def tuple_to_algebraic(pos: tuple[int, int]) -> str {
    row: int;
    col: int;
    (row, col) = pos;  # Tuple unpacking
    col_char: str = chr(ord("a") + col);
    rank: int = 8 - row;
    return rf"{col_char}{rank}";  # Raw f-string
}

# ===================== Move =====================
obj Move {
    has from_pos: tuple[int, int],
        to_pos: tuple[int, int];

    has is_castling: bool = False,
        is_en_passant: bool = False,
        is_promotion: bool = False,
        is_double_push: bool = False;

    has rook_from_col: int = -1,
        rook_to_col: int = -1;

    has captured_piece: Piece | None = None,
        promoted_from: Piece | None = None;

    has prev_has_moved: bool = False,
        prev_ep_pos: tuple[int, int] = (-1, -1);

    has prev_castling_rights: int = 0b1111;  # Binary literal for all castling rights

    def get_from_row() -> int {
        return self.from_pos[0];
    }

    def get_from_col() -> int {
        return self.from_pos[1];
    }

    def get_to_row() -> int {
        return self.to_pos[0];
    }

    def get_to_col() -> int {
        return self.to_pos[1];
    }
}

# ===================== Piece Base =====================
obj Piece {
    has color: Color,
        kind: PieceKind,
        pos: tuple[int, int];  # Using tuple for position

    has has_moved: bool = False;

    def get_row() -> int {
        return self.pos[0];
    }

    def get_col() -> int {
        return self.pos[1];
    }

    def set_pos(row: int, col: int) -> None {
        self.pos = (row, col);
    }

    def get_symbol() -> str {
        if self.color == Color.WHITE {
            return WHITE_SYMBOLS[self.kind];
        }
        return BLACK_SYMBOLS[self.kind];
    }

    def get_raw_moves(board: Board) -> list[Move] {
        return [];
    }

    def slide_moves(board: Board, directions: list[tuple[int, int]]) -> list[Move] {
        moves: list[Move] = [];
        for d in directions {
            dr: int;
            dc: int;
            (dr, dc) = d;  # Tuple unpacking
            r: int = self.get_row() + dr;
            c: int = self.get_col() + dc;
            while board.is_valid_pos(r, c) {
                target: Piece | None = board.get_piece(r, c);
                if target is None {
                    moves.append(
                        Move(from_pos=self.pos, to_pos=(r, c))
                    );
                } elif target.color != self.color {
                    moves.append(
                        Move(from_pos=self.pos, to_pos=(r, c))
                    );
                    break;
                } else {
                    break;
                }
                r += dr;  # Augmented assignment
                c += dc;  # Augmented assignment
            }
        }
        return moves;
    }
}

# ===================== Pawn =====================
obj Pawn(Piece) {
    def get_raw_moves(board: Board) -> list[Move] {
        moves: list[Move] = [];
        direction: int = -1 if self.color == Color.WHITE else 1;
        start_row: int = 6 if self.color == Color.WHITE else 1;
        promo_row: int = 0 if self.color == Color.WHITE else 7;

        row: int = self.get_row();
        col: int = self.get_col();

        # Forward one
        new_row: int = row + direction;
        if board.is_valid_pos(new_row, col)
        and board.get_piece(new_row, col) is None {
            is_promo: bool = new_row == promo_row;
            moves.append(
                Move(
                    from_pos=self.pos,
                    to_pos=(new_row, col),
                    is_promotion=is_promo
                )
            );
            # Forward two from start
            if row == start_row {
                two_row: int = row + 2 * direction;
                if board.get_piece(two_row, col) is None {
                    moves.append(
                        Move(
                            from_pos=self.pos,
                            to_pos=(two_row, col),
                            is_double_push=True
                        )
                    );
                }
            }
        }

        # Diagonal captures using set of offsets
        capture_offsets: set[int] = {-1, 1};  # Set value
        for dc in capture_offsets {
            nc: int = col + dc;
            if board.is_valid_pos(new_row, nc) {
                target: Piece | None = board.get_piece(new_row, nc);
                if target is not None and target.color != self.color {
                    is_promo: bool = new_row == promo_row;
                    moves.append(
                        Move(
                            from_pos=self.pos,
                            to_pos=(new_row, nc),
                            is_promotion=is_promo
                        )
                    );
                }
                # En passant
                ep_row: int;
                ep_col: int;
                (ep_row, ep_col) = board.ep_pos;
                if new_row == ep_row and nc == ep_col {
                    moves.append(
                        Move(
                            from_pos=self.pos,
                            to_pos=(new_row, nc),
                            is_en_passant=True
                        )
                    );
                }
            }
        }

        return moves;
    }
}

# ===================== Knight =====================
obj Knight(Piece) {
    def get_raw_moves(board: Board) -> list[Move] {
        # Knight offsets as list of tuples
        offsets: list[tuple[int, int]] = [
            (-2, -1), (-2, 1), (-1, -2), (-1, 2),
            (1, -2), (1, 2), (2, -1), (2, 1)
        ];

        row: int = self.get_row();
        col: int = self.get_col();

        # Build valid positions list
        valid_positions: list[tuple[int, int]] = [];
        for offset in offsets {
            dr: int = offset[0];
            dc: int = offset[1];
            if board.is_valid_pos(row + dr, col + dc) {
                valid_positions.append((row + dr, col + dc));
            }
        }

        # List comprehension for filtering moves by target square
        moves: list[Move] = [];
        for pos in valid_positions {
            r: int;
            c: int;
            (r, c) = pos;
            target: Piece | None = board.get_piece(r, c);
            if target is None or target.color != self.color {
                moves.append(Move(from_pos=self.pos, to_pos=pos));
            }
        }
        return moves;
    }
}

# ===================== Bishop =====================
obj Bishop(Piece) {
    def get_raw_moves(board: Board) -> list[Move] {
        # Diagonal directions as tuples
        directions: list[tuple[int, int]] = [(-1, -1), (-1, 1), (1, -1), (1, 1)];
        return self.slide_moves(board, directions);
    }
}

# ===================== Rook =====================
obj Rook(Piece) {
    def get_raw_moves(board: Board) -> list[Move] {
        # Orthogonal directions as tuples
        directions: list[tuple[int, int]] = [(-1, 0), (1, 0), (0, -1), (0, 1)];
        return self.slide_moves(board, directions);
    }
}

# ===================== Queen =====================
obj Queen(Piece) {
    def get_raw_moves(board: Board) -> list[Move] {
        # All 8 directions as tuples
        directions: list[tuple[int, int]] = [
            (-1, -1), (-1, 0), (-1, 1), (0, -1),
            (0, 1), (1, -1), (1, 0), (1, 1)
        ];
        return self.slide_moves(board, directions);
    }
}

# ===================== King =====================
obj King(Piece) {
    def get_raw_moves(board: Board) -> list[Move] {
        moves: list[Move] = [];
        row: int = self.get_row();
        col: int = self.get_col();

        # Generate all adjacent positions using list comprehension
        adjacent: list[tuple[int, int]] = [
            (row + dr, col + dc)
            for dr in [-1, 0, 1]
            for dc in [-1, 0, 1]
            if not (dr == 0 and dc == 0)
        ];

        for pos in adjacent {
            r: int;
            c: int;
            (r, c) = pos;
            if board.is_valid_pos(r, c) {
                target: Piece | None = board.get_piece(r, c);
                if target is None or target.color != self.color {
                    moves.append(Move(from_pos=self.pos, to_pos=pos));
                }
            }
        }
        return moves;
    }
}

# ===================== Helper Functions =====================
def opposite_color(color: Color) -> Color {
    if color == Color.WHITE {
        return Color.BLACK;
    }
    return Color.WHITE;
}

def combine_move_lists(list1: list[Move], list2: list[Move]) -> list[Move] {
    # Combine two move lists (varargs not yet supported in native)
    result: list[Move] = [];
    for m in list1 {
        result.append(m);
    }
    for m in list2 {
        result.append(m);
    }
    return result;
}

def count_pieces_by_kind(pieces: list[Piece]) -> dict[PieceKind, int] {
    # Count pieces by kind (sum with generator not yet supported in native)
    counts: dict[PieceKind, int] = {};
    all_kinds: list[PieceKind] = [
        PieceKind.PAWN, PieceKind.KNIGHT, PieceKind.BISHOP,
        PieceKind.ROOK, PieceKind.QUEEN, PieceKind.KING
    ];
    for kind in all_kinds {
        count: int = 0;
        for p in pieces {
            if p.kind == kind {
                count += 1;
            }
        }
        counts[kind] = count;
    }
    return counts;
}

def merge_piece_info(white_pawns: int, black_pawns: int) -> dict[str, int] {
    # Simplified: explicit parameters instead of **kwargs
    result: dict[str, int] = {"white_pawns": white_pawns, "black_pawns": black_pawns};
    return result;
}

def create_piece(kind: PieceKind, color: Color, row: int, col: int) -> Piece {
    pos: tuple[int, int] = (row, col);
    if kind == PieceKind.PAWN {
        return Pawn(color=color, kind=kind, pos=pos);
    } elif kind == PieceKind.KNIGHT {
        return Knight(color=color, kind=kind, pos=pos);
    } elif kind == PieceKind.BISHOP {
        return Bishop(color=color, kind=kind, pos=pos);
    } elif kind == PieceKind.ROOK {
        return Rook(color=color, kind=kind, pos=pos);
    } elif kind == PieceKind.QUEEN {
        return Queen(color=color, kind=kind, pos=pos);
    } else {
        return King(color=color, kind=kind, pos=pos);
    }
}

# Global variable for simple random state (Linear Congruential Generator)
glob _rand_state: int = 12345;

def seed_random(seed: int) -> None {
    global _rand_state;
    _rand_state = seed;
}

def random_int(max_val: int) -> int {
    # Simple LCG random number generator
    global _rand_state;
    _rand_state = (_rand_state * 1103515245 + 12345) % 2147483648;
    if max_val <= 0 {
        return 0;
    }
    return _rand_state % max_val;
}

# ===================== Board =====================
obj Board {
    has squares: list[list[Piece | None]] = [],
        ep_pos: tuple[int, int] = (-1, -1),
        castling_rights: int = 0b1111;  # All castling available initially

    def postinit() {
        # Initialize board using list comprehension
        self.squares = [
            [None for _ in range(BOARD_SIZE)]
            for _ in range(BOARD_SIZE)
        ];
        self.setup_pieces();
    }

    def setup_pieces() -> None {
        back_rank: list[PieceKind] = [
            PieceKind.ROOK, PieceKind.KNIGHT, PieceKind.BISHOP, PieceKind.QUEEN,
            PieceKind.KING, PieceKind.BISHOP, PieceKind.KNIGHT, PieceKind.ROOK
        ];
        for col in range(BOARD_SIZE) {
            self.squares[0][col] = create_piece(back_rank[col], Color.BLACK, 0, col);
            self.squares[1][col] = create_piece(PieceKind.PAWN, Color.BLACK, 1, col);
            self.squares[6][col] = create_piece(PieceKind.PAWN, Color.WHITE, 6, col);
            self.squares[7][col] = create_piece(back_rank[col], Color.WHITE, 7, col);
        }
    }

    def is_valid_pos(row: int, col: int) -> bool {
        return 0 <= row and row < BOARD_SIZE and 0 <= col and col < BOARD_SIZE;
    }

    def get_piece(row: int, col: int) -> Piece | None {
        return self.squares[row][col];
    }

    def set_piece(row: int, col: int, piece: Piece | None) -> None {
        self.squares[row][col] = piece;
    }

    def get_all_pieces(color: Color) -> list[Piece] {
        # List comprehension with nested iteration
        return [
            self.squares[r][c]
            for r in range(BOARD_SIZE)
            for c in range(BOARD_SIZE)
            if self.squares[r][c] is not None and self.squares[r][c].color == color
        ];
    }

    def get_piece_positions(color: Color) -> dict[tuple[int, int], Piece] {
        # Dict comprehension for position -> piece mapping
        return {
            (r, c): self.squares[r][c]
            for r in range(BOARD_SIZE)
            for c in range(BOARD_SIZE)
            if self.squares[r][c] is not None and self.squares[r][c].color == color
        };
    }

    def get_attacked_squares(by_color: Color) -> set[tuple[int, int]] {
        # Build attacked squares using set operations
        attacked: set[tuple[int, int]] = set();
        pieces: list[Piece] = self.get_all_pieces(by_color);
        for piece in pieces {
            moves: list[Move] = piece.get_raw_moves(self);
            # Set comprehension to get target positions from moves
            piece_targets: set[tuple[int, int]] = {m.to_pos for m in moves};
            # Union the sets using |=
            attacked |= piece_targets;
        }
        return attacked;
    }

    def make_move(move: Move) -> None {
        from_row: int = move.get_from_row();
        from_col: int = move.get_from_col();
        to_row: int = move.get_to_row();
        to_col: int = move.get_to_col();

        # Save board state for undo
        move.prev_ep_pos = self.ep_pos;
        move.prev_castling_rights = self.castling_rights;

        piece: Piece | None = self.get_piece(from_row, from_col);
        if piece is None {
            return;
        }
        move.prev_has_moved = piece.has_moved;

        # Handle en passant capture
        if move.is_en_passant {
            ep_pawn_row: int = from_row;
            move.captured_piece = self.get_piece(ep_pawn_row, to_col);
            self.set_piece(ep_pawn_row, to_col, None);
        } else {
            move.captured_piece = self.get_piece(to_row, to_col);
        }

        # Move the piece
        self.set_piece(from_row, from_col, None);
        self.set_piece(to_row, to_col, piece);
        piece.set_pos(to_row, to_col);
        piece.has_moved = True;

        # Update castling rights using bitwise operations
        if piece.kind == PieceKind.KING {
            if piece.color == Color.WHITE {
                self.castling_rights &= ~(CASTLE_WK | CASTLE_WQ);  # Bitwise AND-NOT
            } else {
                self.castling_rights &= ~(CASTLE_BK | CASTLE_BQ);
            }
        } elif piece.kind == PieceKind.ROOK {
            # Rook moved - remove corresponding castling right
            if from_row == 7 and from_col == 0 {
                self.castling_rights &= ~CASTLE_WQ;
            } elif from_row == 7 and from_col == 7 {
                self.castling_rights &= ~CASTLE_WK;
            } elif from_row == 0 and from_col == 0 {
                self.castling_rights &= ~CASTLE_BQ;
            } elif from_row == 0 and from_col == 7 {
                self.castling_rights &= ~CASTLE_BK;
            }
        }

        # Handle promotion (pawn -> queen)
        if move.is_promotion {
            move.promoted_from = piece;
            queen: Piece = Queen(
                color=piece.color,
                kind=PieceKind.QUEEN,
                pos=(to_row, to_col)
            );
            queen.has_moved = True;
            self.set_piece(to_row, to_col, queen);
        }

        # Handle castling (move the rook)
        if move.is_castling {
            rook: Piece | None = self.get_piece(from_row, move.rook_from_col);
            if rook is not None {
                self.set_piece(from_row, move.rook_from_col, None);
                self.set_piece(from_row, move.rook_to_col, rook);
                rook.set_pos(from_row, move.rook_to_col);
                rook.has_moved = True;
            }
        }

        # Update en passant target
        if move.is_double_push {
            ep_dir: int = -1 if piece.color == Color.WHITE else 1;
            self.ep_pos = (from_row + ep_dir, from_col);
        } else {
            self.ep_pos = (-1, -1);
        }
    }

    def undo_move(move: Move) -> None {
        from_row: int = move.get_from_row();
        from_col: int = move.get_from_col();
        to_row: int = move.get_to_row();
        to_col: int = move.get_to_col();

        # Determine the piece to restore
        piece: Piece | None = None;
        if move.is_promotion {
            piece = move.promoted_from;
        } else {
            piece = self.get_piece(to_row, to_col);
        }
        if piece is None {
            return;
        }

        # Move piece back
        self.set_piece(to_row, to_col, None);
        self.set_piece(from_row, from_col, piece);
        piece.set_pos(from_row, from_col);
        piece.has_moved = move.prev_has_moved;

        # Restore captured piece
        if move.is_en_passant {
            ep_pawn_row: int = from_row;
            self.set_piece(ep_pawn_row, to_col, move.captured_piece);
            if move.captured_piece is not None {
                move.captured_piece.set_pos(ep_pawn_row, to_col);
            }
        } else {
            self.set_piece(to_row, to_col, move.captured_piece);
            if move.captured_piece is not None {
                move.captured_piece.set_pos(to_row, to_col);
            }
        }

        # Undo castling
        if move.is_castling {
            rook: Piece | None = self.get_piece(from_row, move.rook_to_col);
            if rook is not None {
                self.set_piece(from_row, move.rook_to_col, None);
                self.set_piece(from_row, move.rook_from_col, rook);
                rook.set_pos(from_row, move.rook_from_col);
                rook.has_moved = False;
            }
        }

        # Restore en passant state and castling rights
        self.ep_pos = move.prev_ep_pos;
        self.castling_rights = move.prev_castling_rights;
    }

    def evaluate_position(color: Color) -> int {
        # Piece values using floor division and power for weighted scoring
        piece_values: dict[PieceKind, int] = {
            PieceKind.PAWN: 100,
            PieceKind.KNIGHT: 320,
            PieceKind.BISHOP: 330,
            PieceKind.ROOK: 500,
            PieceKind.QUEEN: 900,
            PieceKind.KING: 20000
        };

        score: int = 0;
        material_score: int = 0;
        positional_score: int = 0;
        mobility_factor: int = 1;

        for r in range(BOARD_SIZE) {
            for c in range(BOARD_SIZE) {
                piece: Piece | None = self.squares[r][c];
                if piece is not None {
                    base_value: int = piece_values[piece.kind];

                    # Center control bonus using bitwise check
                    center_bonus: int = 0;
                    # Use bitwise AND to check if column is in center (files c-f)
                    col_mask: int = 1 << c;  # Left shift to create column bit
                    if (col_mask & CENTER_MASK) != 0 and 2 <= r and r <= 5 {
                        center_bonus = base_value // 10;  # Floor division
                    }

                    # Piece development bonus (power operation)
                    dev_bonus: int = 0;
                    if piece.has_moved and piece.kind != PieceKind.KING {
                        # Small exponential bonus for development
                        dev_bonus = 2 ** 3;  # Power operator
                    }

                    # Accumulate scores using augmented assignment
                    piece_total: int = base_value;
                    piece_total += center_bonus;  # +=
                    piece_total += dev_bonus;

                    # Apply to material vs positional tracking
                    if piece.color == color {
                        material_score += base_value;
                        positional_score += center_bonus + dev_bonus;
                    } else {
                        material_score -= base_value;
                        positional_score -= center_bonus + dev_bonus;
                    }
                }
            }
        }

        # Combine scores - demonstrate more augmented operators
        score = material_score;
        score += positional_score;  # +=

        # Apply mobility factor using multiplication
        mobility_factor *= 2;  # *=
        mobility_factor //= 2;  # //= floor division assignment (back to 1)

        # Use modulo to add small factor based on position hash
        position_hash: int = material_score % 7;  # Modulo operator
        position_hash %= 5;  # %= modulo assignment
        score += position_hash;

        # Demonstrate XOR for position uniqueness check
        xor_factor: int = 0;
        xor_factor ^= material_score & 0xFF;  # ^= and & operators
        xor_factor ^= positional_score & 0xFF;

        # Shift operations
        shift_val: int = 16;
        shift_val <<= 1;  # <<= left shift assignment (now 32)
        shift_val >>= 2;  # >>= right shift assignment (now 8)

        # Right shift to scale down large values
        scaled_xor: int = xor_factor >> 4;  # Right shift
        score += scaled_xor;
        score += shift_val;

        # Power assignment demonstration
        power_bonus: int = 2;
        power_bonus **= 2;  # **= power assignment (now 4)
        score += power_bonus;

        # Division assignment (using temp to avoid float issues)
        div_temp: int = 100;
        div_temp //= 10;  # //= floor division (now 10)
        score += div_temp;

        return score;
    }

    def display() -> None {
        output: str = "\n   a  b  c  d  e  f  g  h\n";  # Will use augmented assignment

        for r in range(BOARD_SIZE) {
            rank: int = BOARD_SIZE - r;
            output += f"{rank} ";  # Augmented assignment
            for c in range(BOARD_SIZE) {
                piece: Piece | None = self.squares[r][c];
                if piece is not None {
                    output += f" {piece.get_symbol()} ";
                } else {
                    output += " . ";
                }
            }
            output += f" {rank}\n";
        }
        output += "   a  b  c  d  e  f  g  h\n";
        print(output);
    }

    def to_fen_piece_placement() -> str {
        # Build FEN string with augmented assignment
        fen: str = "";
        for r in range(BOARD_SIZE) {
            empty_count: int = 0;
            for c in range(BOARD_SIZE) {
                piece: Piece | None = self.squares[r][c];
                if piece is None {
                    empty_count += 1;
                } else {
                    if empty_count > 0 {
                        fen += str(empty_count);
                        empty_count = 0;
                    }
                    fen += piece.get_symbol();
                }
            }
            if empty_count > 0 {
                fen += str(empty_count);
            }
            if r < 7 {
                fen += "/";
            }
        }
        return fen;
    }
}

# ===================== Game =====================
obj Game {
    has board: Board | None = None,
        current_turn: Color = Color.WHITE,
        is_over: bool = False,
        move_count: int = 0;

    def postinit() {
        self.board = Board();
    }

    def find_king(color: Color) -> Piece | None {
        # Use generator comprehension with next() for lazy evaluation
        pieces: dict[tuple[int, int], Piece] = self.board.get_piece_positions(color);
        for pos in pieces {
            piece: Piece = pieces[pos];
            if piece.kind == PieceKind.KING {
                return piece;
            }
        }
        return None;
    }

    def is_square_attacked(row: int, col: int, by_color: Color) -> bool {
        target_pos: tuple[int, int] = (row, col);
        attacked: set[tuple[int, int]] = self.board.get_attacked_squares(by_color);
        return target_pos in attacked;
    }

    def is_in_check(color: Color) -> bool {
        king: Piece | None = self.find_king(color);
        if king is None {
            return False;
        }
        king_row: int;
        king_col: int;
        (king_row, king_col) = king.pos;  # Tuple unpacking
        return self.is_square_attacked(king_row, king_col, opposite_color(color));
    }

    def get_legal_moves(color: Color) -> list[Move] {
        piece_moves: list[Move] = [];
        castling_moves: list[Move] = [];

        # Use dict comprehension result for iteration
        piece_map: dict[tuple[int, int], Piece] = self.board.get_piece_positions(color);

        for pos in piece_map {
            piece: Piece = piece_map[pos];
            raw: list[Move] = piece.get_raw_moves(self.board);
            for move in raw {
                self.board.make_move(move);
                if not self.is_in_check(color) {
                    piece_moves.append(move);
                }
                self.board.undo_move(move);
            }
        }

        # Add castling moves - check rights using bitwise AND
        king: Piece | None = self.find_king(color);
        if king is not None and not king.has_moved {
            back_rank: int = 7 if color == Color.WHITE else 0;
            opp: Color = opposite_color(color);

            # King-side castling
            ks_right: int = CASTLE_WK if color == Color.WHITE else CASTLE_BK;
            if (self.board.castling_rights & ks_right) != 0 {
                rook_ks: Piece | None = self.board.get_piece(back_rank, 7);
                if (rook_ks is not None and rook_ks.kind == PieceKind.ROOK
                    and not rook_ks.has_moved) {
                    if (self.board.get_piece(back_rank, 5) is None
                        and self.board.get_piece(back_rank, 6) is None) {
                        if (not self.is_in_check(color)
                            and not self.is_square_attacked(back_rank, 5, opp)
                            and not self.is_square_attacked(back_rank, 6, opp)) {
                            castle_move: Move = Move(
                                from_pos=(back_rank, 4),
                                to_pos=(back_rank, 6),
                                is_castling=True,
                                rook_from_col=7,
                                rook_to_col=5
                            );
                            castling_moves.append(castle_move);
                        }
                    }
                }
            }

            # Queen-side castling
            qs_right: int = CASTLE_WQ if color == Color.WHITE else CASTLE_BQ;
            if (self.board.castling_rights & qs_right) != 0 {
                rook_qs: Piece | None = self.board.get_piece(back_rank, 0);
                if (rook_qs is not None and rook_qs.kind == PieceKind.ROOK
                    and not rook_qs.has_moved) {
                    if (self.board.get_piece(back_rank, 1) is None
                        and self.board.get_piece(back_rank, 2) is None
                        and self.board.get_piece(back_rank, 3) is None) {
                        if (not self.is_in_check(color)
                            and not self.is_square_attacked(back_rank, 2, opp)
                            and not self.is_square_attacked(back_rank, 3, opp)) {
                            castle_move: Move = Move(
                                from_pos=(back_rank, 4),
                                to_pos=(back_rank, 2),
                                is_castling=True,
                                rook_from_col=0,
                                rook_to_col=3
                            );
                            castling_moves.append(castle_move);
                        }
                    }
                }
            }
        }

        # Combine piece moves and castling moves using unpack helper
        return combine_move_lists(piece_moves, castling_moves);
    }

    def is_checkmate(color: Color) -> bool {
        return self.is_in_check(color) and len(self.get_legal_moves(color)) == 0;
    }

    def is_stalemate(color: Color) -> bool {
        return not self.is_in_check(color) and len(self.get_legal_moves(color)) == 0;
    }

    def parse_input(text: str) -> tuple[int, int, int, int] | None {
        parts: list[str] = text.strip().split(" ");
        if len(parts) != 2 {
            return None;
        }
        from_sq: str = parts[0];
        to_sq: str = parts[1];
        if len(from_sq) != 2 or len(to_sq) != 2 {
            return None;
        }
        from_col: int = ord(from_sq[0]) - ord("a");
        from_row: int = BOARD_SIZE - int(from_sq[1]);
        to_col: int = ord(to_sq[0]) - ord("a");
        to_row: int = BOARD_SIZE - int(to_sq[1]);
        if (not self.board.is_valid_pos(from_row, from_col)
            or not self.board.is_valid_pos(to_row, to_col)) {
            return None;
        }
        return (from_row, from_col, to_row, to_col);  # Return as tuple
    }

    def get_move_history_summary() -> str {
        # Use modulo and floor division for move numbering
        full_moves: int = self.move_count // 2;  # Floor division
        half_move: int = self.move_count % 2;    # Modulo
        return f"Move {full_moves + 1}" + ("..." if half_move == 1 else "");
    }

    def play() -> None {
        while not self.is_over {
            self.board.display();
            color_name: str = "White" if self.current_turn == Color.WHITE else "Black";

            # Show position evaluation
            eval_score: int = self.board.evaluate_position(Color.WHITE);
            print(f"Position eval: {eval_score} (positive = White advantage)");

            # Show piece counts using generator comprehension helper
            white_pieces: list[Piece] = self.board.get_all_pieces(Color.WHITE);
            black_pieces: list[Piece] = self.board.get_all_pieces(Color.BLACK);
            white_counts: dict[PieceKind, int] = count_pieces_by_kind(white_pieces);
            black_counts: dict[PieceKind, int] = count_pieces_by_kind(black_pieces);

            # Create piece summary
            piece_info: dict[str, int] = merge_piece_info(
                white_counts[PieceKind.PAWN],
                black_counts[PieceKind.PAWN]
            );
            print(f"Pawns - W: {piece_info['white_pawns']}, B: {piece_info['black_pawns']}");

            print(self.get_move_history_summary());

            if self.is_in_check(self.current_turn) {
                print(f"{color_name} is in CHECK!");
            }

            move_str: str = input(f"{color_name}'s turn (e.g. e2 e4, or press Enter for random): ");

            if move_str == "quit" {
                print("Game ended.");
                self.is_over = True;
                return;
            }

            # Get legal moves for current player
            legal_moves: list[Move] = self.get_legal_moves(self.current_turn);

            # Handle empty input - make a random move
            found: Move | None = None;
            move_str = move_str.strip();
            if len(move_str) == 0 {
                if len(legal_moves) == 0 {
                    print("No legal moves available!");
                    continue;
                }
                idx: int = random_int(len(legal_moves));
                found = legal_moves[idx];
                # Show what move was chosen
                from_alg: str = tuple_to_algebraic(found.from_pos);
                to_alg: str = tuple_to_algebraic(found.to_pos);
                print(f"Random move: {from_alg} {to_alg}");
            } else {
                coords: tuple[int, int, int, int] | None = self.parse_input(move_str);
                if coords is None {
                    print("Invalid input. Use format like: e2 e4");
                    continue;
                }

                from_row: int;
                from_col: int;
                to_row: int;
                to_col: int;
                (from_row, from_col, to_row, to_col) = coords;  # Tuple unpacking

                # Check that selected piece belongs to current player
                selected: Piece | None = self.board.get_piece(from_row, from_col);
                if selected is None or selected.color != self.current_turn {
                    print("No valid piece at that square.");
                    continue;
                }

                # Find matching legal move using comprehension filter
                matching: list[Move] = [
                    m for m in legal_moves
                    if m.from_pos == (from_row, from_col) and m.to_pos == (to_row, to_col)
                ];

                if len(matching) == 0 {
                    print("Illegal move. Try again.");
                    continue;
                }

                found = matching[0];
            }

            # Execute
            self.board.make_move(found);
            self.move_count += 1;  # Augmented assignment

            # Switch turns
            self.current_turn = opposite_color(self.current_turn);

            # Check end conditions
            if self.is_checkmate(self.current_turn) {
                self.board.display();
                winner: str = "White" if self.current_turn == Color.BLACK else "Black";
                print(f"Checkmate! {winner} wins!");
                self.is_over = True;
            } elif self.is_stalemate(self.current_turn) {
                self.board.display();
                print("Stalemate! The game is a draw.");
                self.is_over = True;
            }
        }
    }
}

# ===================== Entry Point =====================
with entry {
    game: Game = Game();
    game.play();
}
