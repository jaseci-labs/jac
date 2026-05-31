// A C++ port of the chess engine that mirrors the Jac implementation's types
// and logic faithfully:
//   obj            -> class (with inheritance where Jac has it)
//   Piece | None   -> std::shared_ptr<Piece>  (refcounted, nullable, polymorphic)
//   obj Move       -> std::shared_ptr<Move>   (reference object, like Jac)
//   tuple[int,int] -> std::pair<int,int>
//   list[...]      -> std::vector<...>
//   dict / set     -> std::map / std::set
//   override       -> virtual method override
// Only the play_auto benchmark path is ported (no display/evaluation), matching
// the other backends. Build: c++ -O2 -o chess_cpp other_langs/chess.cpp
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <cstdlib>
#include <memory>
#include <vector>
#include <map>
#include <set>
#include <utility>
#include <string>

enum class Color { WHITE = 0, BLACK = 1 };
enum class PieceKind { PAWN = 0, KNIGHT = 1, BISHOP = 2, ROOK = 3, QUEEN = 4, KING = 5 };

static const int BOARD_SIZE = 8;
static const int CASTLE_WK = 0x01, CASTLE_WQ = 0x02, CASTLE_BK = 0x04,
                 CASTLE_BQ = 0x08, CASTLE_ALL = 0x0F;

using Pos = std::pair<int, int>;

class Board;
class Piece;
struct Move;
using PiecePtr = std::shared_ptr<Piece>;
using MovePtr = std::shared_ptr<Move>;

// ────────────────────── Piece (base) ──────────────────────
class Piece {
public:
    Color color;
    PieceKind kind;
    Pos pos;
    bool has_moved;
    Piece(Color c, PieceKind k, Pos p) : color(c), kind(k), pos(p), has_moved(false) {}
    virtual ~Piece() = default;
    int row() const { return pos.first; }
    int col() const { return pos.second; }
    void set_pos(int r, int c) { pos = {r, c}; }
    virtual std::vector<MovePtr> raw_moves(Board& board);
    std::vector<MovePtr> slide_moves(Board& board, const std::vector<Pos>& directions);
};

class Pawn : public Piece { public: using Piece::Piece; std::vector<MovePtr> raw_moves(Board& board) override; };
class Knight : public Piece { public: using Piece::Piece; std::vector<MovePtr> raw_moves(Board& board) override; };
class Bishop : public Piece { public: using Piece::Piece; std::vector<MovePtr> raw_moves(Board& board) override; };
class Rook : public Piece { public: using Piece::Piece; std::vector<MovePtr> raw_moves(Board& board) override; };
class Queen : public Piece { public: using Piece::Piece; std::vector<MovePtr> raw_moves(Board& board) override; };
class King : public Piece { public: using Piece::Piece; std::vector<MovePtr> raw_moves(Board& board) override; };

// ────────────────────── Move ──────────────────────
struct Move {
    Pos from_pos, to_pos;
    bool is_castling, is_en_passant, is_promotion, is_double_push;
    int rook_from_col, rook_to_col;
    PiecePtr captured_piece, promoted_from;
    bool prev_has_moved;
    Pos prev_ep_pos;
    int prev_castling_rights;
    Move(Pos from, Pos to, bool promo = false, bool dpush = false, bool ep = false,
         bool castling = false, int rfc = -1, int rtc = -1)
        : from_pos(from), to_pos(to), is_castling(castling), is_en_passant(ep),
          is_promotion(promo), is_double_push(dpush), rook_from_col(rfc), rook_to_col(rtc),
          captured_piece(nullptr), promoted_from(nullptr), prev_has_moved(false),
          prev_ep_pos({-1, -1}), prev_castling_rights(CASTLE_ALL) {}
    int from_row() const { return from_pos.first; }
    int from_col() const { return from_pos.second; }
    int to_row() const { return to_pos.first; }
    int to_col() const { return to_pos.second; }
};

// ────────────────────── Board ──────────────────────
class Board {
public:
    std::vector<std::vector<PiecePtr>> squares;
    Pos ep_pos;
    int castling_rights;
    Board() : ep_pos({-1, -1}), castling_rights(CASTLE_ALL) {
        squares.assign(BOARD_SIZE, std::vector<PiecePtr>(BOARD_SIZE, nullptr));
        setup_pieces();
    }
    void setup_pieces();
    bool valid_pos(int r, int c) { return r >= 0 && r < BOARD_SIZE && c >= 0 && c < BOARD_SIZE; }
    PiecePtr at(int r, int c) { return squares[r][c]; }
    void put(int r, int c, PiecePtr p) { squares[r][c] = p; }
    std::vector<PiecePtr> pieces_of(Color color);
    std::map<Pos, PiecePtr> piece_map(Color color);
    std::set<Pos> attacked_squares(Color by_color);
    void make_move(const MovePtr& move);
    void undo_move(const MovePtr& move);
};

// ────────────────────── Game ──────────────────────
class Game {
public:
    Board board;
    Color current_turn;
    bool is_over;
    int move_count;
    Game() : current_turn(Color::WHITE), is_over(false), move_count(0) {}
    PiecePtr find_king(Color color);
    bool square_attacked(int row, int col, Color by_color);
    bool in_check(Color color);
    std::vector<MovePtr> legal_moves(Color color);
    bool is_checkmate(Color color);
    bool is_stalemate(Color color);
    std::string play_auto();
    void benchmark(int num_games);
};

// ────────────────────── Free functions ──────────────────────
static Color opposite_color(Color c) { return c == Color::WHITE ? Color::BLACK : Color::WHITE; }

static uint64_t _rand_state = 12345;
static void seed_random(uint64_t s) { _rand_state = s; }
static int random_int(int max_val) {
    _rand_state = (_rand_state * 1103515245ULL + 12345ULL) % 2147483648ULL;
    if (max_val <= 0) return 0;
    return (int)(_rand_state % (uint64_t)max_val);
}

static PiecePtr create_piece(PieceKind kind, Color color, int row, int col) {
    Pos pos{row, col};
    switch (kind) {
    case PieceKind::PAWN:   return std::make_shared<Pawn>(color, kind, pos);
    case PieceKind::KNIGHT: return std::make_shared<Knight>(color, kind, pos);
    case PieceKind::BISHOP: return std::make_shared<Bishop>(color, kind, pos);
    case PieceKind::ROOK:   return std::make_shared<Rook>(color, kind, pos);
    case PieceKind::QUEEN:  return std::make_shared<Queen>(color, kind, pos);
    default:                return std::make_shared<King>(color, kind, pos);
    }
}

// ────────────────────── Piece move generation ──────────────────────
std::vector<MovePtr> Piece::raw_moves(Board&) { return {}; }

std::vector<MovePtr> Piece::slide_moves(Board& board, const std::vector<Pos>& directions) {
    std::vector<MovePtr> moves;
    for (const auto& d : directions) {
        int dr = d.first, dc = d.second;
        int r = row() + dr, c = col() + dc;
        while (board.valid_pos(r, c)) {
            PiecePtr target = board.at(r, c);
            if (!target) {
                moves.push_back(std::make_shared<Move>(pos, Pos{r, c}));
            } else if (target->color != color) {
                moves.push_back(std::make_shared<Move>(pos, Pos{r, c}));
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

std::vector<MovePtr> Pawn::raw_moves(Board& board) {
    std::vector<MovePtr> moves;
    int direction = (color == Color::WHITE) ? -1 : 1;
    int start_row = (color == Color::WHITE) ? 6 : 1;
    int promo_row = (color == Color::WHITE) ? 0 : 7;
    int r = row(), c = col();
    int new_row = r + direction;
    if (board.valid_pos(new_row, c) && !board.at(new_row, c)) {
        bool is_promo = (new_row == promo_row);
        moves.push_back(std::make_shared<Move>(pos, Pos{new_row, c}, is_promo));
        if (r == start_row) {
            int two_row = r + 2 * direction;
            if (!board.at(two_row, c))
                moves.push_back(std::make_shared<Move>(pos, Pos{two_row, c}, false, true));
        }
    }
    for (int dc : {-1, 1}) {
        int nc = c + dc;
        if (board.valid_pos(new_row, nc)) {
            PiecePtr target = board.at(new_row, nc);
            if (target && target->color != color) {
                bool is_promo = (new_row == promo_row);
                moves.push_back(std::make_shared<Move>(pos, Pos{new_row, nc}, is_promo));
            }
            if (new_row == board.ep_pos.first && nc == board.ep_pos.second)
                moves.push_back(std::make_shared<Move>(pos, Pos{new_row, nc}, false, false, true));
        }
    }
    return moves;
}

std::vector<MovePtr> Knight::raw_moves(Board& board) {
    static const int off[8][2] = {{-2,-1},{-2,1},{-1,-2},{-1,2},{1,-2},{1,2},{2,-1},{2,1}};
    int r = row(), c = col();
    std::vector<MovePtr> moves;
    for (const auto& o : off) {
        int rr = r + o[0], cc = c + o[1];
        if (board.valid_pos(rr, cc)) {
            PiecePtr target = board.at(rr, cc);
            if (!target || target->color != color)
                moves.push_back(std::make_shared<Move>(pos, Pos{rr, cc}));
        }
    }
    return moves;
}

std::vector<MovePtr> Bishop::raw_moves(Board& board) {
    return slide_moves(board, {{-1,-1},{-1,1},{1,-1},{1,1}});
}
std::vector<MovePtr> Rook::raw_moves(Board& board) {
    return slide_moves(board, {{-1,0},{1,0},{0,-1},{0,1}});
}
std::vector<MovePtr> Queen::raw_moves(Board& board) {
    return slide_moves(board, {{-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}});
}

std::vector<MovePtr> King::raw_moves(Board& board) {
    std::vector<MovePtr> moves;
    int r = row(), c = col();
    for (int dr : {-1, 0, 1})
        for (int dc : {-1, 0, 1}) {
            if (dr == 0 && dc == 0) continue;
            int rr = r + dr, cc = c + dc;
            if (board.valid_pos(rr, cc)) {
                PiecePtr target = board.at(rr, cc);
                if (!target || target->color != color)
                    moves.push_back(std::make_shared<Move>(pos, Pos{rr, cc}));
            }
        }
    return moves;
}

// ────────────────────── Board logic ──────────────────────
void Board::setup_pieces() {
    PieceKind back[8] = {PieceKind::ROOK, PieceKind::KNIGHT, PieceKind::BISHOP,
                         PieceKind::QUEEN, PieceKind::KING, PieceKind::BISHOP,
                         PieceKind::KNIGHT, PieceKind::ROOK};
    for (int c = 0; c < BOARD_SIZE; c++) {
        squares[0][c] = create_piece(back[c], Color::BLACK, 0, c);
        squares[1][c] = create_piece(PieceKind::PAWN, Color::BLACK, 1, c);
        squares[6][c] = create_piece(PieceKind::PAWN, Color::WHITE, 6, c);
        squares[7][c] = create_piece(back[c], Color::WHITE, 7, c);
    }
}

std::vector<PiecePtr> Board::pieces_of(Color color) {
    std::vector<PiecePtr> result;
    for (int r = 0; r < BOARD_SIZE; r++)
        for (int c = 0; c < BOARD_SIZE; c++) {
            PiecePtr p = squares[r][c];
            if (p && p->color == color) result.push_back(p);
        }
    return result;
}

std::map<Pos, PiecePtr> Board::piece_map(Color color) {
    std::map<Pos, PiecePtr> m;
    for (int r = 0; r < BOARD_SIZE; r++)
        for (int c = 0; c < BOARD_SIZE; c++) {
            PiecePtr p = squares[r][c];
            if (p && p->color == color) m[{r, c}] = p;
        }
    return m;
}

std::set<Pos> Board::attacked_squares(Color by_color) {
    std::set<Pos> attacked;
    for (auto& piece : pieces_of(by_color))
        for (auto& m : piece->raw_moves(*this))
            attacked.insert(m->to_pos);
    return attacked;
}

void Board::make_move(const MovePtr& move) {
    int fr = move->from_row(), fc = move->from_col(), tr = move->to_row(), tc = move->to_col();
    move->prev_ep_pos = ep_pos;
    move->prev_castling_rights = castling_rights;
    PiecePtr piece = at(fr, fc);
    if (!piece) return;
    move->prev_has_moved = piece->has_moved;
    if (move->is_en_passant) {
        move->captured_piece = at(fr, tc);
        put(fr, tc, nullptr);
    } else {
        move->captured_piece = at(tr, tc);
    }
    put(fr, fc, nullptr);
    put(tr, tc, piece);
    piece->set_pos(tr, tc);
    piece->has_moved = true;
    if (piece->kind == PieceKind::KING) {
        if (piece->color == Color::WHITE) castling_rights &= ~(CASTLE_WK | CASTLE_WQ);
        else castling_rights &= ~(CASTLE_BK | CASTLE_BQ);
    } else if (piece->kind == PieceKind::ROOK) {
        if (fr == 7 && fc == 0) castling_rights &= ~CASTLE_WQ;
        else if (fr == 7 && fc == 7) castling_rights &= ~CASTLE_WK;
        else if (fr == 0 && fc == 0) castling_rights &= ~CASTLE_BQ;
        else if (fr == 0 && fc == 7) castling_rights &= ~CASTLE_BK;
    }
    if (move->is_promotion) {
        move->promoted_from = piece;
        PiecePtr queen = std::make_shared<Queen>(piece->color, PieceKind::QUEEN, Pos{tr, tc});
        queen->has_moved = true;
        put(tr, tc, queen);
    }
    if (move->is_castling) {
        PiecePtr rook = at(fr, move->rook_from_col);
        if (rook) {
            put(fr, move->rook_from_col, nullptr);
            put(fr, move->rook_to_col, rook);
            rook->set_pos(fr, move->rook_to_col);
            rook->has_moved = true;
        }
    }
    if (move->is_double_push) {
        int ep_dir = (piece->color == Color::WHITE) ? -1 : 1;
        ep_pos = {fr + ep_dir, fc};
    } else {
        ep_pos = {-1, -1};
    }
}

void Board::undo_move(const MovePtr& move) {
    int fr = move->from_row(), fc = move->from_col(), tr = move->to_row(), tc = move->to_col();
    PiecePtr piece = move->is_promotion ? move->promoted_from : at(tr, tc);
    if (!piece) return;
    put(tr, tc, nullptr);
    put(fr, fc, piece);
    piece->set_pos(fr, fc);
    piece->has_moved = move->prev_has_moved;
    if (move->is_en_passant) {
        put(fr, tc, move->captured_piece);
        if (move->captured_piece) move->captured_piece->set_pos(fr, tc);
    } else {
        put(tr, tc, move->captured_piece);
        if (move->captured_piece) move->captured_piece->set_pos(tr, tc);
    }
    if (move->is_castling) {
        PiecePtr rook = at(fr, move->rook_to_col);
        if (rook) {
            put(fr, move->rook_to_col, nullptr);
            put(fr, move->rook_from_col, rook);
            rook->set_pos(fr, move->rook_from_col);
            rook->has_moved = false;
        }
    }
    ep_pos = move->prev_ep_pos;
    castling_rights = move->prev_castling_rights;
}

// ────────────────────── Game logic ──────────────────────
PiecePtr Game::find_king(Color color) {
    auto positions = board.piece_map(color);
    for (auto& kv : positions) {
        PiecePtr piece = kv.second;
        if (piece->kind == PieceKind::KING) return piece;
    }
    return nullptr;
}

bool Game::square_attacked(int row, int col, Color by_color) {
    auto attacked = board.attacked_squares(by_color);
    return attacked.count({row, col}) > 0;
}

bool Game::in_check(Color color) {
    PiecePtr king = find_king(color);
    if (!king) return false;
    return square_attacked(king->pos.first, king->pos.second, opposite_color(color));
}

std::vector<MovePtr> Game::legal_moves(Color color) {
    std::vector<MovePtr> moves;
    auto pmap = board.piece_map(color);
    for (auto& kv : pmap) {
        PiecePtr piece = kv.second;
        for (auto& move : piece->raw_moves(board)) {
            board.make_move(move);
            if (!in_check(color)) moves.push_back(move);
            board.undo_move(move);
        }
    }
    PiecePtr king = find_king(color);
    if (king && !king->has_moved) {
        int back = (color == Color::WHITE) ? 7 : 0;
        Color opp = opposite_color(color);
        int ks = (color == Color::WHITE) ? CASTLE_WK : CASTLE_BK;
        if (board.castling_rights & ks) {
            PiecePtr rook = board.at(back, 7);
            if (rook && rook->kind == PieceKind::ROOK && !rook->has_moved) {
                if (!board.at(back, 5) && !board.at(back, 6)) {
                    if (!in_check(color) && !square_attacked(back, 5, opp) && !square_attacked(back, 6, opp))
                        moves.push_back(std::make_shared<Move>(Pos{back, 4}, Pos{back, 6}, false, false, false, true, 7, 5));
                }
            }
        }
        int qs = (color == Color::WHITE) ? CASTLE_WQ : CASTLE_BQ;
        if (board.castling_rights & qs) {
            PiecePtr rook = board.at(back, 0);
            if (rook && rook->kind == PieceKind::ROOK && !rook->has_moved) {
                if (!board.at(back, 1) && !board.at(back, 2) && !board.at(back, 3)) {
                    if (!in_check(color) && !square_attacked(back, 2, opp) && !square_attacked(back, 3, opp))
                        moves.push_back(std::make_shared<Move>(Pos{back, 4}, Pos{back, 2}, false, false, false, true, 0, 3));
                }
            }
        }
    }
    return moves;
}

bool Game::is_checkmate(Color color) { return in_check(color) && legal_moves(color).empty(); }
bool Game::is_stalemate(Color color) { return !in_check(color) && legal_moves(color).empty(); }

std::string Game::play_auto() {
    int max_moves = 500;
    while (!is_over && move_count < max_moves) {
        auto all_legal = legal_moves(current_turn);
        if (all_legal.empty()) {
            if (in_check(current_turn)) return (current_turn == Color::BLACK) ? "White" : "Black";
            return "Draw";
        }
        int idx = random_int((int)all_legal.size());
        MovePtr chosen = all_legal[idx];
        board.make_move(chosen);
        move_count++;
        current_turn = opposite_color(current_turn);
        if (is_checkmate(current_turn)) return (current_turn == Color::BLACK) ? "White" : "Black";
        else if (is_stalemate(current_turn)) return "Draw";
    }
    return "Draw";
}

void Game::benchmark(int num_games) {
    int white = 0, black = 0, draws = 0;
    printf("Running %d games...\n\n", num_games);
    for (int i = 0; i < num_games; i++) {
        Game g;
        seed_random((uint64_t)(i * 7919 + 42));
        std::string result = g.play_auto();
        if (result == "White") { white++; printf("Game %d: White wins\n", i + 1); }
        else if (result == "Black") { black++; printf("Game %d: Black wins\n", i + 1); }
        else { draws++; printf("Game %d: Draw\n", i + 1); }
    }
    printf("\n--- Results (%d games) ---\n", num_games);
    printf("White wins: %d\n", white);
    printf("Black wins: %d\n", black);
    printf("Draws:      %d\n", draws);
}

int main(int argc, char** argv) {
    int bench = 20;
    for (int i = 1; i < argc; i++) {
        if ((strcmp(argv[i], "--benchmark") == 0 || strcmp(argv[i], "-b") == 0) && i + 1 < argc)
            bench = atoi(argv[i + 1]);
    }
    if (bench > 0) { Game game; game.benchmark(bench); }
    return 0;
}
