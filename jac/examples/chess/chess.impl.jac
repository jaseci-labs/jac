"""Chess engine — all method implementations."""

# ────────────────────── Free functions ──────────────────────
impl opposite_color(color: Color) -> Color {
    if color == Color.WHITE {
        return Color.BLACK;
    }
    return Color.WHITE;
}

impl to_algebraic(pos: tuple[int, int]) -> str {
    (row, col) = pos;
    col_char = chr(ord("a") + col);
    rank = 8 - row;
    return f"{col_char}{rank}";
}

impl create_piece(kind: PieceKind, color: Color, row: int, col: int) -> Piece {
    pos = (row, col);
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

impl seed_random(seed: int) -> None {
    global _rand_state;
    _rand_state = seed;
}

impl random_int(max_val: int) -> int {
    global _rand_state;
    _rand_state = (_rand_state * 1103515245 + 12345) % 2147483648;
    if max_val <= 0 {
        return 0;
    }
    return _rand_state % max_val;
}

# ────────────────────── Move ──────────────────────
impl Move.from_row -> int {
    return self.from_pos[0];
}

impl Move.from_col -> int {
    return self.from_pos[1];
}

impl Move.to_row -> int {
    return self.to_pos[0];
}

impl Move.to_col -> int {
    return self.to_pos[1];
}

# ────────────────────── Piece (base) ──────────────────────
impl Piece.row -> int {
    return self.pos[0];
}

impl Piece.col -> int {
    return self.pos[1];
}

impl Piece.set_pos(row: int, col: int) -> None {
    self.pos = (row, col);
}

impl Piece.symbol -> str {
    if self.color == Color.WHITE {
        return WHITE_SYMBOLS[self.kind];
    }
    return BLACK_SYMBOLS[self.kind];
}

impl Piece.raw_moves(board: Board) -> list[Move] {
    return [];
}

impl Piece.slide_moves(board: Board, directions: list[tuple[int, int]]) -> list[Move] {
    moves: list[Move] = [];
    for d in directions {
        (dr, dc) = d;
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

# ────────────────────── Pawn ──────────────────────
impl Pawn.raw_moves(board: Board) -> list[Move] {
    moves: list[Move] = [];
    direction = -1 if self.color == Color.WHITE else 1;
    start_row = 6 if self.color == Color.WHITE else 1;
    promo_row = 0 if self.color == Color.WHITE else 7;
    row = self.row();
    col = self.col();

    # One square forward
    new_row = row + direction;
    if board.valid_pos(new_row, col) and board.at(new_row, col) is None {
        is_promo = new_row == promo_row;
        moves.append(
            Move(from_pos=self.pos, to_pos=(new_row, col), is_promotion=is_promo)
        );
        # Two squares from starting rank
        if row == start_row {
            two_row = row + 2 * direction;
            if board.at(two_row, col) is None {
                moves.append(
                    Move(from_pos=self.pos, to_pos=(two_row, col), is_double_push=True)
                );
            }
        }
    }

    # Diagonal captures and en passant
    for dc in [-1, 1] {
        nc = col + dc;
        if board.valid_pos(new_row, nc) {
            target: Piece | None = board.at(new_row, nc);
            if target is not None and target.color != self.color {
                is_promo = new_row == promo_row;
                moves.append(
                    Move(
                        from_pos=self.pos, to_pos=(new_row, nc), is_promotion=is_promo
                    )
                );
            }
            (ep_row, ep_col) = board.ep_pos;
            if new_row == ep_row and nc == ep_col {
                moves.append(
                    Move(from_pos=self.pos, to_pos=(new_row, nc), is_en_passant=True)
                );
            }
        }
    }

    return moves;
}

# ────────────────────── Knight ──────────────────────
impl Knight.raw_moves(board: Board) -> list[Move] {
    offsets: list[tuple[int, int]] = [
        (-2, -1),
        (-2, 1),
        (-1, -2),
        (-1, 2),
        (1, -2),
        (1, 2),
        (2, -1),
        (2, 1)
    ];
    row = self.row();
    col = self.col();

    moves: list[Move] = [];
    for offset in offsets {
        (dr, dc) = offset;
        r = row + dr;
        c = col + dc;
        if board.valid_pos(r, c) {
            target: Piece | None = board.at(r, c);
            if target is None or target.color != self.color {
                moves.append(Move(from_pos=self.pos, to_pos=(r, c)));
            }
        }
    }
    return moves;
}

impl Bishop.raw_moves(board: Board) -> list[Move] {
    return self.slide_moves(board, [(-1, -1), (-1, 1), (1, -1), (1, 1)]);
}

impl Rook.raw_moves(board: Board) -> list[Move] {
    return self.slide_moves(board, [(-1, 0), (1, 0), (0, -1), (0, 1)]);
}

impl Queen.raw_moves(board: Board) -> list[Move] {
    return self.slide_moves(
        board, [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
    );
}

# ────────────────────── King ──────────────────────
impl King.raw_moves(board: Board) -> list[Move] {
    moves: list[Move] = [];
    row = self.row();
    col = self.col();

    adjacent: list[tuple[int, int]] = [
        (row + dr, col + dc) for dr in [-1, 0, 1]
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

# ────────────────────── Board ──────────────────────
impl Board.postinit{
    self.squares = [[None for _ in range(BOARD_SIZE)] for _ in range(BOARD_SIZE)];
    self.setup_pieces();
}

impl Board.setup_pieces -> None {
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
    for col in range(BOARD_SIZE) {
        self.squares[0][col] = create_piece(back_rank[col], Color.BLACK, 0, col);
        self.squares[1][col] = create_piece(PieceKind.PAWN, Color.BLACK, 1, col);
        self.squares[6][col] = create_piece(PieceKind.PAWN, Color.WHITE, 6, col);
        self.squares[7][col] = create_piece(back_rank[col], Color.WHITE, 7, col);
    }
}

impl Board.valid_pos(row: int, col: int) -> bool {
    return 0 <= row and row < BOARD_SIZE and 0 <= col and col < BOARD_SIZE;
}

impl Board.at(row: int, col: int) -> Piece | None {
    return self.squares[row][col];
}

impl Board.put(row: int, col: int, piece: Piece | None) -> None {
    self.squares[row][col] = piece;
}

impl Board.pieces_of(color: Color) -> list[Piece] {
    return [
        self.squares[r][c] for r in range(BOARD_SIZE)
        for c in range(BOARD_SIZE)
        if self.squares[r][c] is not None and self.squares[r][c].color == color
    ];
}

impl Board.piece_map(color: Color) -> dict[tuple[int, int], Piece] {
    return {
        (r, c): self.squares[r][c] for r in range(BOARD_SIZE)
        for c in range(BOARD_SIZE)
        if self.squares[r][c] is not None and self.squares[r][c].color == color
    };
}

impl Board.attacked_squares(by_color: Color) -> set[tuple[int, int]] {
    attacked: set[tuple[int, int]] = set();
    for piece in self.pieces_of(by_color) {
        attacked |= {m.to_pos for m in piece.raw_moves(self)};
    }
    return attacked;
}

impl Board.make_move(move: Move) -> None {
    fr = move.from_row();
    fc = move.from_col();
    tr = move.to_row();
    tc = move.to_col();

    # Snapshot for undo
    move.prev_ep_pos = self.ep_pos;
    move.prev_castling_rights = self.castling_rights;

    piece: Piece | None = self.at(fr, fc);
    if piece is None {
        return;
    }
    move.prev_has_moved = piece.has_moved;

    # Capture
    if move.is_en_passant {
        move.captured_piece = self.at(fr, tc);
        self.put(fr, tc, None);
    } else {
        move.captured_piece = self.at(tr, tc);
    }

    # Relocate piece
    self.put(fr, fc, None);
    self.put(tr, tc, piece);
    piece.set_pos(tr, tc);
    piece.has_moved = True;

    # Update castling rights
    if piece.kind == PieceKind.KING {
        if piece.color == Color.WHITE {
            self.castling_rights &= ~(CASTLE_WK | CASTLE_WQ);
        } else {
            self.castling_rights &= ~(CASTLE_BK | CASTLE_BQ);
        }
    } elif piece.kind == PieceKind.ROOK {
        if fr == 7 and fc == 0 {
            self.castling_rights &= ~CASTLE_WQ;
        } elif fr == 7 and fc == 7 {
            self.castling_rights &= ~CASTLE_WK;
        } elif fr == 0 and fc == 0 {
            self.castling_rights &= ~CASTLE_BQ;
        } elif fr == 0 and fc == 7 {
            self.castling_rights &= ~CASTLE_BK;
        }
    }

    # Promotion (always to queen)
    if move.is_promotion {
        move.promoted_from = piece;
        queen = Queen(color=piece.color, kind=PieceKind.QUEEN, pos=(tr, tc));
        queen.has_moved = True;
        self.put(tr, tc, queen);
    }

    # Castling — move the rook
    if move.is_castling {
        rook: Piece | None = self.at(fr, move.rook_from_col);
        if rook is not None {
            self.put(fr, move.rook_from_col, None);
            self.put(fr, move.rook_to_col, rook);
            rook.set_pos(fr, move.rook_to_col);
            rook.has_moved = True;
        }
    }

    # En passant target
    if move.is_double_push {
        ep_dir = -1 if piece.color == Color.WHITE else 1;
        self.ep_pos = (fr + ep_dir, fc);
    } else {
        self.ep_pos = (-1, -1);
    }
}

impl Board.undo_move(move: Move) -> None {
    fr = move.from_row();
    fc = move.from_col();
    tr = move.to_row();
    tc = move.to_col();

    piece: Piece | None = None;
    if move.is_promotion {
        piece = move.promoted_from;
    } else {
        piece = self.at(tr, tc);
    }
    if piece is None {
        return;
    }

    # Move piece back
    self.put(tr, tc, None);
    self.put(fr, fc, piece);
    piece.set_pos(fr, fc);
    piece.has_moved = move.prev_has_moved;

    # Restore captured piece
    if move.is_en_passant {
        self.put(fr, tc, move.captured_piece);
        if move.captured_piece is not None {
            move.captured_piece.set_pos(fr, tc);
        }
    } else {
        self.put(tr, tc, move.captured_piece);
        if move.captured_piece is not None {
            move.captured_piece.set_pos(tr, tc);
        }
    }

    # Undo castling
    if move.is_castling {
        rook: Piece | None = self.at(fr, move.rook_to_col);
        if rook is not None {
            self.put(fr, move.rook_to_col, None);
            self.put(fr, move.rook_from_col, rook);
            rook.set_pos(fr, move.rook_from_col);
            rook.has_moved = False;
        }
    }

    # Restore state
    self.ep_pos = move.prev_ep_pos;
    self.castling_rights = move.prev_castling_rights;
}

impl Board.evaluate(color: Color) -> int {
    score = 0;
    for r in range(BOARD_SIZE) {
        for c in range(BOARD_SIZE) {
            piece: Piece | None = self.squares[r][c];
            if piece is not None {
                base = PIECE_VALUES[piece.kind];

                # Center control bonus
                center_bonus = 0;
                if (1 << c & CENTER_MASK) != 0 and 2 <= r and r <= 5 {
                    center_bonus = base // 10;
                }

                # Development bonus
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

impl Board.display -> None {
    output: str = "\n   a  b  c  d  e  f  g  h\n";
    for r in range(BOARD_SIZE) {
        rank = BOARD_SIZE - r;
        output += f"{rank} ";
        for c in range(BOARD_SIZE) {
            piece: Piece | None = self.squares[r][c];
            if piece is not None {
                output += f" {piece.symbol()} ";
            } else {
                output += " . ";
            }
        }
        output += f" {rank}\n";
    }
    output += "   a  b  c  d  e  f  g  h\n";
    print(output);
}

impl Board.fen_placement -> str {
    fen: str = "";
    for r in range(BOARD_SIZE) {
        empty = 0;
        for c in range(BOARD_SIZE) {
            piece: Piece | None = self.squares[r][c];
            if piece is None {
                empty += 1;
            } else {
                if empty > 0 {
                    fen += str(empty);
                    empty = 0;
                }
                fen += piece.symbol();
            }
        }
        if empty > 0 {
            fen += str(empty);
        }
        if r < 7 {
            fen += "/";
        }
    }
    return fen;
}

# ────────────────────── Game ──────────────────────
impl Game.postinit{
    self.board = Board();
}

impl Game.find_king(color: Color) -> Piece | None {
    positions: dict[tuple[int, int], Piece] = self.board.piece_map(color);
    for pos in positions {
        piece: Piece = positions[pos];
        if piece.kind == PieceKind.KING {
            return piece;
        }
    }
    return None;
}

impl Game.square_attacked(row: int, col: int, by_color: Color) -> bool {
    return (row, col) in self.board.attacked_squares(by_color);
}

impl Game.in_check(color: Color) -> bool {
    king: Piece | None = self.find_king(color);
    if king is None {
        return False;
    }
    (kr, kc) = king.pos;
    return self.square_attacked(kr, kc, opposite_color(color));
}

impl Game.legal_moves(color: Color) -> list[Move] {
    moves: list[Move] = [];
    pmap: dict[tuple[int, int], Piece] = self.board.piece_map(color);

    for pos in pmap {
        piece: Piece = pmap[pos];
        for move in piece.raw_moves(self.board) {
            self.board.make_move(move);
            if not self.in_check(color) {
                moves.append(move);
            }
            self.board.undo_move(move);
        }
    }

    # Castling
    king: Piece | None = self.find_king(color);
    if king is not None and not king.has_moved {
        back = 7 if color == Color.WHITE else 0;
        opp = opposite_color(color);

        # King-side
        ks = CASTLE_WK if color == Color.WHITE else CASTLE_BK;
        if (self.board.castling_rights & ks) != 0 {
            rook: Piece | None = self.board.at(back, 7);
            if rook is not None
            and rook.kind == PieceKind.ROOK
            and not rook.has_moved {
                if self.board.at(back, 5) is None and self.board.at(back, 6) is None {
                    if (
                        not self.in_check(color)
                        and not self.square_attacked(back, 5, opp)
                        and not self.square_attacked(back, 6, opp)
                    ) {
                        moves.append(
                            Move(
                                from_pos=(back, 4),
                                to_pos=(back, 6),
                                is_castling=True,
                                rook_from_col=7,
                                rook_to_col=5
                            )
                        );
                    }
                }
            }
        }

        # Queen-side
        qs = CASTLE_WQ if color == Color.WHITE else CASTLE_BQ;
        if (self.board.castling_rights & qs) != 0 {
            rook: Piece | None = self.board.at(back, 0);
            if rook is not None
            and rook.kind == PieceKind.ROOK
            and not rook.has_moved {
                if (
                    self.board.at(back, 1) is None
                    and self.board.at(back, 2) is None
                    and self.board.at(back, 3) is None
                ) {
                    if (
                        not self.in_check(color)
                        and not self.square_attacked(back, 2, opp)
                        and not self.square_attacked(back, 3, opp)
                    ) {
                        moves.append(
                            Move(
                                from_pos=(back, 4),
                                to_pos=(back, 2),
                                is_castling=True,
                                rook_from_col=0,
                                rook_to_col=3
                            )
                        );
                    }
                }
            }
        }
    }

    return moves;
}

impl Game.is_checkmate(color: Color) -> bool {
    return self.in_check(color) and len(self.legal_moves(color)) == 0;
}

impl Game.is_stalemate(color: Color) -> bool {
    return not self.in_check(color) and len(self.legal_moves(color)) == 0;
}

impl Game.parse_input(text: str) -> tuple[int, int, int, int] | None {
    parts: list[str] = text.strip().split(" ");
    if len(parts) != 2 {
        return None;
    }
    from_sq = parts[0];
    to_sq = parts[1];
    if len(from_sq) != 2 or len(to_sq) != 2 {
        return None;
    }
    fc = ord(from_sq[0]) - ord("a");
    fr = BOARD_SIZE - int(from_sq[1]);
    tc = ord(to_sq[0]) - ord("a");
    tr = BOARD_SIZE - int(to_sq[1]);
    if not self.board.valid_pos(fr, fc) or not self.board.valid_pos(tr, tc) {
        return None;
    }
    return (fr, fc, tr, tc);
}

impl Game.move_summary -> str {
    full_moves = self.move_count // 2;
    half = self.move_count % 2;
    return f"Move {full_moves + 1}" + ("..." if half == 1 else "");
}

impl Game.play_auto -> str {
    """Play one full game with random moves. Returns 'White', 'Black', or 'Draw'."""
    max_moves = 500;
    while not self.is_over and self.move_count < max_moves {
        all_legal: list[Move] = self.legal_moves(self.current_turn);
        if len(all_legal) == 0 {
            if self.in_check(self.current_turn) {
                winner = "White" if self.current_turn == Color.BLACK else "Black";
                return winner;
            } else {
                return "Draw";
            }
        }
        idx = random_int(len(all_legal));
        chosen = all_legal[idx];
        self.board.make_move(chosen);
        self.move_count += 1;
        self.current_turn = opposite_color(self.current_turn);

        if self.is_checkmate(self.current_turn) {
            winner = "White" if self.current_turn == Color.BLACK else "Black";
            return winner;
        } elif self.is_stalemate(self.current_turn) {
            return "Draw";
        }
    }
    return "Draw";
}

impl Game.benchmark(num_games: int) -> None {
    """Run num_games automated random games and print results."""
    white_wins = 0;
    black_wins = 0;
    draws = 0;

    print(f"Running {num_games} games...\n");

    for i in range(num_games) {
        g = Game();
        seed_random(i * 7919 + 42);
        result = g.play_auto();

        if result == "White" {
            white_wins += 1;
        } elif result == "Black" {
            black_wins += 1;
        } else {
            draws += 1;
        }
        print(
            f"Game {i + 1}: {result} wins"
                if result != "Draw"
                else f"Game {i + 1}: Draw"
        );
    }

    print(f"\n--- Results ({num_games} games) ---");
    print(f"White wins: {white_wins}");
    print(f"Black wins: {black_wins}");
    print(f"Draws:      {draws}");
}

impl Game.play -> None {
    while not self.is_over {
        self.board.display();
        color_name = "White" if self.current_turn == Color.WHITE else "Black";

        eval_score = self.board.evaluate(Color.WHITE);
        print(f"Position eval: {eval_score} (positive = White advantage)");
        print(self.move_summary());

        if self.in_check(self.current_turn) {
            print(f"{color_name} is in CHECK!");
        }

        move_str = input(
            f"{color_name}'s turn (e.g. e2 e4, or press Enter for random): "
        );

        if move_str == "quit" {
            print("Game ended.");
            self.is_over = True;
            return;
        }

        all_legal: list[Move] = self.legal_moves(self.current_turn);
        found: Move | None = None;
        move_str = move_str.strip();

        if len(move_str) == 0 {
            if len(all_legal) == 0 {
                print("No legal moves available!");
                continue;
            }
            idx = random_int(len(all_legal));
            found = all_legal[idx];
            print(
                f"Random move: {to_algebraic(found.from_pos)} {to_algebraic(
                    found.to_pos
                )}"
            );
        } else {
            coords: tuple[int, int, int, int] | None = self.parse_input(move_str);
            if coords is None {
                print("Invalid input. Use format like: e2 e4");
                continue;
            }
            (fr, fc, tr, tc) = coords;
            selected: Piece | None = self.board.at(fr, fc);
            if selected is None or selected.color != self.current_turn {
                print("No valid piece at that square.");
                continue;
            }
            matching: list[Move] = [
                m
                for m in all_legal
                if m.from_pos == (fr, fc) and m.to_pos == (tr, tc)
            ];
            if len(matching) == 0 {
                print("Illegal move. Try again.");
                continue;
            }
            found = matching[0];
        }

        self.board.make_move(found);
        self.move_count += 1;
        self.current_turn = opposite_color(self.current_turn);

        if self.is_checkmate(self.current_turn) {
            self.board.display();
            winner = "White" if self.current_turn == Color.BLACK else "Black";
            print(f"Checkmate! {winner} wins!");
            self.is_over = True;
        } elif self.is_stalemate(self.current_turn) {
            self.board.display();
            print("Stalemate! The game is a draw.");
            self.is_over = True;
        }
    }
}
