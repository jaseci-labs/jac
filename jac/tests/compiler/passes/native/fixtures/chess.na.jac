"""Chess game in Jac - native compilation reference implementation.

Uses obj inheritance with strict typing and no dynamic features.
Designed as the target spec for na {} codegen buildout.
"""

# ===================== Enums =====================
enum Color { WHITE = 0, BLACK = 1 }

enum PieceKind { PAWN = 0, KNIGHT = 1, BISHOP = 2, ROOK = 3, QUEEN = 4, KING = 5 }

# ===================== Forward Declarations =====================
obj Board;
obj Piece;

# ===================== Move =====================
obj Move {
    has from_row: int,
        from_col: int,
        to_row: int,
        to_col: int;

    has is_castling: bool = False,
        is_en_passant: bool = False,
        is_promotion: bool = False,
        is_double_push: bool = False;

    has rook_from_col: int = -1,
        rook_to_col: int = -1;

    has captured_piece: Piece | None = None,
        promoted_from: Piece | None = None;

    has prev_has_moved: bool = False,
        prev_ep_row: int = -1,
        prev_ep_col: int = -1;
}

# ===================== Piece Base =====================
obj Piece {
    has color: Color,
        kind: PieceKind,
        row: int,
        col: int;

    has has_moved: bool = False;

    def get_symbol() -> str {
        return "?";
    }

    def get_raw_moves(board: Board) -> list[Move] {
        return [];
    }

    def slide_moves(board: Board, directions: list[list[int]]) -> list[Move] {
        moves: list[Move] = [];
        for d in directions {
            dr: int = d[0];
            dc: int = d[1];
            r: int = self.row + dr;
            c: int = self.col + dc;
            while board.is_valid_pos(r, c) {
                target: Piece | None = board.get_piece(r, c);
                if target is None {
                    moves.append(
                        Move(from_row=self.row, from_col=self.col, to_row=r, to_col=c)
                    );
                } elif target.color != self.color {
                    moves.append(
                        Move(from_row=self.row, from_col=self.col, to_row=r, to_col=c)
                    );
                    break;
                } else {
                    break;
                }
                r = r + dr;
                c = c + dc;
            }
        }
        return moves;
    }
}

# ===================== Pawn =====================
obj Pawn(Piece) {
    def get_symbol() -> str {
        if self.color == Color.WHITE {
            return "P";
        }
        return "p";
    }

    def get_raw_moves(board: Board) -> list[Move] {
        moves: list[Move] = [];
        direction: int = -1 if self.color == Color.WHITE else 1;
        start_row: int = 6 if self.color == Color.WHITE else 1;
        promo_row: int = 0 if self.color == Color.WHITE else 7;

        # Forward one
        new_row: int = self.row + direction;
        if board.is_valid_pos(new_row, self.col)
        and board.get_piece(new_row, self.col) is None {
            is_promo: bool = new_row == promo_row;
            moves.append(
                Move(
                    from_row=self.row,
                    from_col=self.col,
                    to_row=new_row,
                    to_col=self.col,
                    is_promotion=is_promo
                )
            );
            # Forward two from start
            if self.row == start_row {
                two_row: int = self.row + 2 * direction;
                if board.get_piece(two_row, self.col) is None {
                    moves.append(
                        Move(
                            from_row=self.row,
                            from_col=self.col,
                            to_row=two_row,
                            to_col=self.col,
                            is_double_push=True
                        )
                    );
                }
            }
        }

        # Diagonal captures
        for dc in [-1, 1] {
            nc: int = self.col + dc;
            if board.is_valid_pos(new_row, nc) {
                target: Piece | None = board.get_piece(new_row, nc);
                if target is not None and target.color != self.color {
                    is_promo: bool = new_row == promo_row;
                    moves.append(
                        Move(
                            from_row=self.row,
                            from_col=self.col,
                            to_row=new_row,
                            to_col=nc,
                            is_promotion=is_promo
                        )
                    );
                }
                # En passant
                if new_row == board.ep_row and nc == board.ep_col {
                    moves.append(
                        Move(
                            from_row=self.row,
                            from_col=self.col,
                            to_row=new_row,
                            to_col=nc,
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
    def get_symbol() -> str {
        if self.color == Color.WHITE {
            return "N";
        }
        return "n";
    }

    def get_raw_moves(board: Board) -> list[Move] {
        moves: list[Move] = [];
        offsets: list[list[int]] = [
            [-2, -1],
            [-2, 1],
            [-1, -2],
            [-1, 2],
            [1, -2],
            [1, 2],
            [2, -1],
            [2, 1]
        ];
        for off in offsets {
            r: int = self.row + off[0];
            c: int = self.col + off[1];
            if board.is_valid_pos(r, c) {
                target: Piece | None = board.get_piece(r, c);
                if target is None or target.color != self.color {
                    moves.append(
                        Move(from_row=self.row, from_col=self.col, to_row=r, to_col=c)
                    );
                }
            }
        }
        return moves;
    }
}

# ===================== Bishop =====================
obj Bishop(Piece) {
    def get_symbol() -> str {
        if self.color == Color.WHITE {
            return "B";
        }
        return "b";
    }

    def get_raw_moves(board: Board) -> list[Move] {
        return self.slide_moves(board, [[-1, -1], [-1, 1], [1, -1], [1, 1]]);
    }
}

# ===================== Rook =====================
obj Rook(Piece) {
    def get_symbol() -> str {
        if self.color == Color.WHITE {
            return "R";
        }
        return "r";
    }

    def get_raw_moves(board: Board) -> list[Move] {
        return self.slide_moves(board, [[-1, 0], [1, 0], [0, -1], [0, 1]]);
    }
}

# ===================== Queen =====================
obj Queen(Piece) {
    def get_symbol() -> str {
        if self.color == Color.WHITE {
            return "Q";
        }
        return "q";
    }

    def get_raw_moves(board: Board) -> list[Move] {
        return self.slide_moves(
            board,
            [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]]
        );
    }
}

# ===================== King =====================
obj King(Piece) {
    def get_symbol() -> str {
        if self.color == Color.WHITE {
            return "K";
        }
        return "k";
    }

    def get_raw_moves(board: Board) -> list[Move] {
        moves: list[Move] = [];
        for dr in [-1, 0, 1] {
            for dc in [-1, 0, 1] {
                if dr == 0 and dc == 0 {
                    continue;
                }
                r: int = self.row + dr;
                c: int = self.col + dc;
                if board.is_valid_pos(r, c) {
                    target: Piece | None = board.get_piece(r, c);
                    if target is None or target.color != self.color {
                        moves.append(
                            Move(
                                from_row=self.row,
                                from_col=self.col,
                                to_row=r,
                                to_col=c
                            )
                        );
                    }
                }
            }
        }
        return moves;
    }
}

# ===================== Helper Functions =====================
def opposite_color(
    color: Color
) -> Color {
    if color == Color.WHITE {
        return Color.BLACK;
    }
    return Color.WHITE;
}

def create_piece(kind: PieceKind, color: Color, row: int, col: int) -> Piece {
    if kind == PieceKind.PAWN {
        return Pawn(color=color, kind=kind, row=row, col=col);
    } elif kind == PieceKind.KNIGHT {
        return Knight(color=color, kind=kind, row=row, col=col);
    } elif kind == PieceKind.BISHOP {
        return Bishop(color=color, kind=kind, row=row, col=col);
    } elif kind == PieceKind.ROOK {
        return Rook(color=color, kind=kind, row=row, col=col);
    } elif kind == PieceKind.QUEEN {
        return Queen(color=color, kind=kind, row=row, col=col);
    } else {
        return King(color=color, kind=kind, row=row, col=col);
    }
}

# ===================== Board =====================
obj Board {
    has squares: list[list[Piece | None]] = [],
        ep_row: int = -1,
        ep_col: int = -1;

    def postinit() {
        self.squares = [];
        for i in range(8) {
            row: list[Piece | None] = [];
            for j in range(8) {
                row.append(None);
            }
            self.squares.append(row);
        }
        self.setup_pieces();
    }

    def setup_pieces() -> None {
        back_rank: list[PieceKind] = [
            PieceKind.ROOK,
            PieceKind.KNIGHT,
            PieceKind.BISHOP,
            PieceKind.QUEEN,
            PieceKind.KING,
            PieceKind.BISHOP,
            PieceKind.KNIGHT,
            PieceKind.ROOK
        ];
        for col in range(8) {
            self.squares[0][col] = create_piece(back_rank[col], Color.BLACK, 0, col);
            self.squares[1][col] = create_piece(PieceKind.PAWN, Color.BLACK, 1, col);
            self.squares[6][col] = create_piece(PieceKind.PAWN, Color.WHITE, 6, col);
            self.squares[7][col] = create_piece(back_rank[col], Color.WHITE, 7, col);
        }
    }

    def is_valid_pos(row: int, col: int) -> bool {
        return 0 <= row and row < 8 and 0 <= col and col < 8;
    }

    def get_piece(row: int, col: int) -> Piece | None {
        return self.squares[row][col];
    }

    def set_piece(row: int, col: int, piece: Piece | None) -> None {
        self.squares[row][col] = piece;
    }

    def make_move(move: Move) -> None {
        # Save board state for undo
        move.prev_ep_row = self.ep_row;
        move.prev_ep_col = self.ep_col;

        piece: Piece | None = self.get_piece(move.from_row, move.from_col);
        if piece is None {
            return;
        }
        move.prev_has_moved = piece.has_moved;

        # Handle en passant capture
        if move.is_en_passant {
            ep_pawn_row: int = move.from_row;
            move.captured_piece = self.get_piece(ep_pawn_row, move.to_col);
            self.set_piece(ep_pawn_row, move.to_col, None);
        } else {
            move.captured_piece = self.get_piece(move.to_row, move.to_col);
        }

        # Move the piece
        self.set_piece(move.from_row, move.from_col, None);
        self.set_piece(move.to_row, move.to_col, piece);
        piece.row = move.to_row;
        piece.col = move.to_col;
        piece.has_moved = True;

        # Handle promotion (pawn -> queen)
        if move.is_promotion {
            move.promoted_from = piece;
            queen: Piece = Queen(
                color=piece.color,
                kind=PieceKind.QUEEN,
                row=move.to_row,
                col=move.to_col
            );
            queen.has_moved = True;
            self.set_piece(move.to_row, move.to_col, queen);
        }

        # Handle castling (move the rook)
        if move.is_castling {
            rook: Piece | None = self.get_piece(move.from_row, move.rook_from_col);
            if rook is not None {
                self.set_piece(move.from_row, move.rook_from_col, None);
                self.set_piece(move.from_row, move.rook_to_col, rook);
                rook.row = move.from_row;
                rook.col = move.rook_to_col;
                rook.has_moved = True;
            }
        }

        # Update en passant target
        if move.is_double_push {
            ep_dir: int = -1 if piece.color == Color.WHITE else 1;
            self.ep_row = move.from_row + ep_dir;
            self.ep_col = move.from_col;
        } else {
            self.ep_row = -1;
            self.ep_col = -1;
        }
    }

    def undo_move(move: Move) -> None {
        # Determine the piece to restore
        piece: Piece | None = None;
        if move.is_promotion {
            piece = move.promoted_from;
        } else {
            piece = self.get_piece(move.to_row, move.to_col);
        }
        if piece is None {
            return;
        }

        # Move piece back
        self.set_piece(move.to_row, move.to_col, None);
        self.set_piece(move.from_row, move.from_col, piece);
        piece.row = move.from_row;
        piece.col = move.from_col;
        piece.has_moved = move.prev_has_moved;

        # Restore captured piece
        if move.is_en_passant {
            ep_pawn_row: int = move.from_row;
            self.set_piece(ep_pawn_row, move.to_col, move.captured_piece);
            if move.captured_piece is not None {
                move.captured_piece.row = ep_pawn_row;
                move.captured_piece.col = move.to_col;
            }
        } else {
            self.set_piece(move.to_row, move.to_col, move.captured_piece);
            if move.captured_piece is not None {
                move.captured_piece.row = move.to_row;
                move.captured_piece.col = move.to_col;
            }
        }

        # Undo castling
        if move.is_castling {
            rook: Piece | None = self.get_piece(move.from_row, move.rook_to_col);
            if rook is not None {
                self.set_piece(move.from_row, move.rook_to_col, None);
                self.set_piece(move.from_row, move.rook_from_col, rook);
                rook.row = move.from_row;
                rook.col = move.rook_from_col;
                rook.has_moved = False;
            }
        }

        # Restore en passant state
        self.ep_row = move.prev_ep_row;
        self.ep_col = move.prev_ep_col;
    }

    def display() -> None {
        print("");
        print("   a  b  c  d  e  f  g  h");
        for r in range(8) {
            rank: int = 8 - r;
            row_str: str = f"{rank} ";
            for c in range(8) {
                piece: Piece | None = self.squares[r][c];
                if piece is not None {
                    row_str = row_str + f" {piece.get_symbol()} ";
                } else {
                    row_str = row_str + " . ";
                }
            }
            row_str = row_str + f" {rank}";
            print(row_str);
        }
        print("   a  b  c  d  e  f  g  h");
        print("");
    }
}

# ===================== Game =====================
obj Game {
    has board: Board | None = None,
        current_turn: Color = Color.WHITE,
        is_over: bool = False;

    def postinit() {
        self.board = Board();
    }

    def find_king(color: Color) -> Piece | None {
        for r in range(8) {
            for c in range(8) {
                piece: Piece | None = self.board.get_piece(r, c);
                if piece is not None
                and piece.kind == PieceKind.KING
                and piece.color == color {
                    return piece;
                }
            }
        }
        return None;
    }

    def is_square_attacked(row: int, col: int, by_color: Color) -> bool {
        for r in range(8) {
            for c in range(8) {
                piece: Piece | None = self.board.get_piece(r, c);
                if piece is not None and piece.color == by_color {
                    raw: list[Move] = piece.get_raw_moves(self.board);
                    for m in raw {
                        if m.to_row == row and m.to_col == col {
                            return True;
                        }
                    }
                }
            }
        }
        return False;
    }

    def is_in_check(color: Color) -> bool {
        king: Piece | None = self.find_king(color);
        if king is None {
            return False;
        }
        return self.is_square_attacked(king.row, king.col, opposite_color(color));
    }

    def get_legal_moves(color: Color) -> list[Move] {
        legal: list[Move] = [];

        # Collect raw moves for all pieces and filter by check
        for r in range(8) {
            for c in range(8) {
                piece: Piece | None = self.board.get_piece(r, c);
                if piece is not None and piece.color == color {
                    raw: list[Move] = piece.get_raw_moves(self.board);
                    for move in raw {
                        self.board.make_move(move);
                        if not self.is_in_check(color) {
                            legal.append(move);
                        }
                        self.board.undo_move(move);
                    }
                }
            }
        }

        # Add castling moves
        king: Piece | None = self.find_king(color);
        if king is not None and not king.has_moved {
            back_rank: int = 7 if color == Color.WHITE else 0;
            opp: Color = opposite_color(color);
            # King-side castling (king e -> g, rook h -> f)
            rook_ks: Piece | None = self.board.get_piece(back_rank, 7);
            if (
                rook_ks is not None
                and rook_ks.kind == PieceKind.ROOK
                and not rook_ks.has_moved
            ) {
                if (
                    self.board.get_piece(back_rank, 5) is None
                    and self.board.get_piece(back_rank, 6) is None
                ) {
                    if (
                        not self.is_in_check(color)
                        and not self.is_square_attacked(back_rank, 5, opp)
                        and not self.is_square_attacked(back_rank, 6, opp)
                    ) {
                        castle_move: Move = Move(
                            from_row=back_rank,
                            from_col=4,
                            to_row=back_rank,
                            to_col=6,
                            is_castling=True,
                            rook_from_col=7,
                            rook_to_col=5
                        );
                        legal.append(castle_move);
                    }
                }
            }
            # Queen-side castling (king e -> c, rook a -> d)
            rook_qs: Piece | None = self.board.get_piece(back_rank, 0);
            if (
                rook_qs is not None
                and rook_qs.kind == PieceKind.ROOK
                and not rook_qs.has_moved
            ) {
                if (
                    self.board.get_piece(back_rank, 1) is None
                    and self.board.get_piece(back_rank, 2) is None
                    and self.board.get_piece(back_rank, 3) is None
                ) {
                    if (
                        not self.is_in_check(color)
                        and not self.is_square_attacked(back_rank, 2, opp)
                        and not self.is_square_attacked(back_rank, 3, opp)
                    ) {
                        castle_move: Move = Move(
                            from_row=back_rank,
                            from_col=4,
                            to_row=back_rank,
                            to_col=2,
                            is_castling=True,
                            rook_from_col=0,
                            rook_to_col=3
                        );
                        legal.append(castle_move);
                    }
                }
            }
        }

        return legal;
    }

    def is_checkmate(color: Color) -> bool {
        return self.is_in_check(color) and len(self.get_legal_moves(color)) == 0;
    }

    def is_stalemate(color: Color) -> bool {
        return not self.is_in_check(color) and len(self.get_legal_moves(color)) == 0;
    }

    def parse_input(text: str) -> list[int] {
        parts: list[str] = text.strip().split(" ");
        if len(parts) != 2 {
            return [];
        }
        from_sq: str = parts[0];
        to_sq: str = parts[1];
        if len(from_sq) != 2 or len(to_sq) != 2 {
            return [];
        }
        from_col: int = ord(from_sq[0]) - ord("a");
        from_row: int = 8 - int(from_sq[1]);
        to_col: int = ord(to_sq[0]) - ord("a");
        to_row: int = 8 - int(to_sq[1]);
        if (
            not self.board.is_valid_pos(from_row, from_col)
            or not self.board.is_valid_pos(to_row, to_col)
        ) {
            return [];
        }
        return [from_row, from_col, to_row, to_col];
    }

    def play() -> None {
        while not self.is_over {
            self.board.display();
            color_name: str = "White" if self.current_turn == Color.WHITE else "Black";

            if self.is_in_check(self.current_turn) {
                print(f"{color_name} is in CHECK!");
            }

            move_str: str = input(f"{color_name}'s turn (e.g. e2 e4): ");

            if move_str == "quit" {
                print("Game ended.");
                self.is_over = True;
                return;
            }

            coords: list[int] = self.parse_input(move_str);
            if len(coords) != 4 {
                print("Invalid input. Use format like: e2 e4");
                continue;
            }

            from_row: int = coords[0];
            from_col: int = coords[1];
            to_row: int = coords[2];
            to_col: int = coords[3];

            # Check that selected piece belongs to current player
            selected: Piece | None = self.board.get_piece(from_row, from_col);
            if selected is None or selected.color != self.current_turn {
                print("No valid piece at that square.");
                continue;
            }

            # Find matching legal move
            legal_moves: list[Move] = self.get_legal_moves(self.current_turn);
            found: Move | None = None;
            for move in legal_moves {
                if (
                    move.from_row == from_row
                    and move.from_col == from_col
                    and move.to_row == to_row
                    and move.to_col == to_col
                ) {
                    found = move;
                    break;
                }
            }

            if found is None {
                print("Illegal move. Try again.");
                continue;
            }

            # Execute
            self.board.make_move(found);

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
