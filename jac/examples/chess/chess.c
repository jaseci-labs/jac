/* A C port of the same chess engine used by chess.py / chess.jac, for a
 * performance curiosity. Replicates the LCG random, per-game seeding, move
 * generation order, and the play_auto benchmark exactly, so the game outcomes
 * match the other backends. Only the benchmark path is ported (no display,
 * evaluation, or human play). Build: cc -O2 -o chess_c chess.c */
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>

#define BOARD_SIZE 8
#define CASTLE_WK 1
#define CASTLE_WQ 2
#define CASTLE_BK 4
#define CASTLE_BQ 8
#define CASTLE_ALL 15

enum { WHITE = 0, BLACK = 1 };
enum { PAWN = 0, KNIGHT = 1, BISHOP = 2, ROOK = 3, QUEEN = 4, KING = 5, EMPTY = -1 };

typedef struct { int kind; int color; bool has_moved; } Piece;

typedef struct {
    int from_r, from_c, to_r, to_c;
    bool is_castling, is_en_passant, is_promotion, is_double_push;
    int rook_from_col, rook_to_col;
    /* undo state, filled by make_move */
    Piece captured;       /* kind==EMPTY if nothing captured */
    Piece promoted_from;  /* original pawn, for promotion undo */
    bool prev_has_moved;
    int prev_ep_r, prev_ep_c;
    int prev_castling_rights;
} Move;

typedef struct {
    Piece sq[BOARD_SIZE][BOARD_SIZE];  /* kind==EMPTY means empty square */
    int ep_r, ep_c;                    /* en-passant target, (-1,-1) if none */
    int castling_rights;
    int current_turn;
    bool is_over;
    int move_count;
} Game;

static uint64_t rand_state = 12345;
static void seed_random(uint64_t s) { rand_state = s; }
static int random_int(int max_val) {
    rand_state = (rand_state * 1103515245ULL + 12345ULL) % 2147483648ULL;
    if (max_val <= 0) return 0;
    return (int)(rand_state % (uint64_t)max_val);
}
static int opposite_color(int c) { return c == WHITE ? BLACK : WHITE; }
static bool valid_pos(int r, int c) { return r >= 0 && r < BOARD_SIZE && c >= 0 && c < BOARD_SIZE; }

static void setup_pieces(Game *g) {
    int back[8] = { ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK };
    for (int c = 0; c < 8; c++) {
        g->sq[0][c] = (Piece){ back[c], BLACK, false };
        g->sq[1][c] = (Piece){ PAWN, BLACK, false };
        g->sq[6][c] = (Piece){ PAWN, WHITE, false };
        g->sq[7][c] = (Piece){ back[c], WHITE, false };
    }
}
static void game_init(Game *g) {
    for (int r = 0; r < 8; r++) for (int c = 0; c < 8; c++) g->sq[r][c].kind = EMPTY;
    g->ep_r = -1; g->ep_c = -1; g->castling_rights = CASTLE_ALL;
    g->current_turn = WHITE; g->is_over = false; g->move_count = 0;
    setup_pieces(g);
}

static void add_move(Move *buf, int *n, int fr, int fc, int tr, int tc,
                     bool promo, bool dpush, bool ep) {
    Move m; memset(&m, 0, sizeof(m));
    m.from_r = fr; m.from_c = fc; m.to_r = tr; m.to_c = tc;
    m.is_promotion = promo; m.is_double_push = dpush; m.is_en_passant = ep;
    m.rook_from_col = -1; m.rook_to_col = -1;
    buf[(*n)++] = m;
}

static void slide_moves(Game *g, int r, int c, int color, int dirs[][2], int ndir,
                        Move *buf, int *n) {
    for (int d = 0; d < ndir; d++) {
        int dr = dirs[d][0], dc = dirs[d][1];
        int rr = r + dr, cc = c + dc;
        while (valid_pos(rr, cc)) {
            Piece *t = &g->sq[rr][cc];
            if (t->kind == EMPTY) { add_move(buf, n, r, c, rr, cc, false, false, false); }
            else if (t->color != color) { add_move(buf, n, r, c, rr, cc, false, false, false); break; }
            else break;
            rr += dr; cc += dc;
        }
    }
}

static void raw_moves(Game *g, int r, int c, Move *buf, int *n) {
    Piece p = g->sq[r][c];
    int color = p.color;
    switch (p.kind) {
    case PAWN: {
        int dir = (color == WHITE) ? -1 : 1;
        int start_row = (color == WHITE) ? 6 : 1;
        int promo_row = (color == WHITE) ? 0 : 7;
        int new_row = r + dir;
        if (valid_pos(new_row, c) && g->sq[new_row][c].kind == EMPTY) {
            add_move(buf, n, r, c, new_row, c, new_row == promo_row, false, false);
            if (r == start_row) {
                int two_row = r + 2 * dir;
                if (g->sq[two_row][c].kind == EMPTY)
                    add_move(buf, n, r, c, two_row, c, false, true, false);
            }
        }
        int dcs[2] = { -1, 1 };
        for (int k = 0; k < 2; k++) {
            int nc = c + dcs[k];
            if (valid_pos(new_row, nc)) {
                Piece *t = &g->sq[new_row][nc];
                if (t->kind != EMPTY && t->color != color)
                    add_move(buf, n, r, c, new_row, nc, new_row == promo_row, false, false);
                if (new_row == g->ep_r && nc == g->ep_c)
                    add_move(buf, n, r, c, new_row, nc, false, false, true);
            }
        }
        break;
    }
    case KNIGHT: {
        int off[8][2] = { {-2,-1},{-2,1},{-1,-2},{-1,2},{1,-2},{1,2},{2,-1},{2,1} };
        for (int k = 0; k < 8; k++) {
            int rr = r + off[k][0], cc = c + off[k][1];
            if (valid_pos(rr, cc)) {
                Piece *t = &g->sq[rr][cc];
                if (t->kind == EMPTY || t->color != color)
                    add_move(buf, n, r, c, rr, cc, false, false, false);
            }
        }
        break;
    }
    case BISHOP: { int d[4][2] = { {-1,-1},{-1,1},{1,-1},{1,1} }; slide_moves(g, r, c, color, d, 4, buf, n); break; }
    case ROOK:   { int d[4][2] = { {-1,0},{1,0},{0,-1},{0,1} }; slide_moves(g, r, c, color, d, 4, buf, n); break; }
    case QUEEN:  { int d[8][2] = { {-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1} }; slide_moves(g, r, c, color, d, 8, buf, n); break; }
    case KING: {
        int drs[3] = { -1, 0, 1 };
        for (int a = 0; a < 3; a++) for (int b = 0; b < 3; b++) {
            int dr = drs[a], dc = drs[b];
            if (dr == 0 && dc == 0) continue;
            int rr = r + dr, cc = c + dc;
            if (valid_pos(rr, cc)) {
                Piece *t = &g->sq[rr][cc];
                if (t->kind == EMPTY || t->color != color)
                    add_move(buf, n, r, c, rr, cc, false, false, false);
            }
        }
        break;
    }
    default: break;
    }
}

/* Matches the engine's attacked-squares semantics: built from raw_moves, so a
 * pawn only "attacks" a diagonal when an enemy piece is actually there. */
static bool square_attacked(Game *g, int r, int c, int by_color) {
    Move buf[64];
    for (int rr = 0; rr < 8; rr++) for (int cc = 0; cc < 8; cc++) {
        Piece p = g->sq[rr][cc];
        if (p.kind != EMPTY && p.color == by_color) {
            int n = 0; raw_moves(g, rr, cc, buf, &n);
            for (int i = 0; i < n; i++)
                if (buf[i].to_r == r && buf[i].to_c == c) return true;
        }
    }
    return false;
}

static bool find_king(Game *g, int color, int *kr, int *kc) {
    for (int r = 0; r < 8; r++) for (int c = 0; c < 8; c++) {
        Piece p = g->sq[r][c];
        if (p.kind == KING && p.color == color) { *kr = r; *kc = c; return true; }
    }
    return false;
}

static bool in_check(Game *g, int color) {
    int kr, kc;
    if (!find_king(g, color, &kr, &kc)) return false;
    return square_attacked(g, kr, kc, opposite_color(color));
}

static void make_move(Game *g, Move *mv) {
    int fr = mv->from_r, fc = mv->from_c, tr = mv->to_r, tc = mv->to_c;
    mv->prev_ep_r = g->ep_r; mv->prev_ep_c = g->ep_c;
    mv->prev_castling_rights = g->castling_rights;
    Piece piece = g->sq[fr][fc];
    if (piece.kind == EMPTY) { mv->captured.kind = EMPTY; return; }
    mv->prev_has_moved = piece.has_moved;
    if (mv->is_en_passant) { mv->captured = g->sq[fr][tc]; g->sq[fr][tc].kind = EMPTY; }
    else { mv->captured = g->sq[tr][tc]; }
    g->sq[fr][fc].kind = EMPTY;
    piece.has_moved = true;
    g->sq[tr][tc] = piece;
    if (piece.kind == KING) {
        if (piece.color == WHITE) g->castling_rights &= ~(CASTLE_WK | CASTLE_WQ);
        else g->castling_rights &= ~(CASTLE_BK | CASTLE_BQ);
    } else if (piece.kind == ROOK) {
        if (fr == 7 && fc == 0) g->castling_rights &= ~CASTLE_WQ;
        else if (fr == 7 && fc == 7) g->castling_rights &= ~CASTLE_WK;
        else if (fr == 0 && fc == 0) g->castling_rights &= ~CASTLE_BQ;
        else if (fr == 0 && fc == 7) g->castling_rights &= ~CASTLE_BK;
    }
    if (mv->is_promotion) {
        mv->promoted_from = piece;
        g->sq[tr][tc] = (Piece){ QUEEN, piece.color, true };
    }
    if (mv->is_castling) {
        Piece rook = g->sq[fr][mv->rook_from_col];
        if (rook.kind != EMPTY) {
            g->sq[fr][mv->rook_from_col].kind = EMPTY;
            rook.has_moved = true;
            g->sq[fr][mv->rook_to_col] = rook;
        }
    }
    if (mv->is_double_push) {
        int ep_dir = (piece.color == WHITE) ? -1 : 1;
        g->ep_r = fr + ep_dir; g->ep_c = fc;
    } else { g->ep_r = -1; g->ep_c = -1; }
}

static void undo_move(Game *g, Move *mv) {
    int fr = mv->from_r, fc = mv->from_c, tr = mv->to_r, tc = mv->to_c;
    Piece piece = mv->is_promotion ? mv->promoted_from : g->sq[tr][tc];
    if (piece.kind == EMPTY) return;
    g->sq[tr][tc].kind = EMPTY;
    piece.has_moved = mv->prev_has_moved;
    g->sq[fr][fc] = piece;
    if (mv->is_en_passant) g->sq[fr][tc] = mv->captured;
    else g->sq[tr][tc] = mv->captured;
    if (mv->is_castling) {
        Piece rook = g->sq[fr][mv->rook_to_col];
        if (rook.kind != EMPTY) {
            g->sq[fr][mv->rook_to_col].kind = EMPTY;
            rook.has_moved = false;
            g->sq[fr][mv->rook_from_col] = rook;
        }
    }
    g->ep_r = mv->prev_ep_r; g->ep_c = mv->prev_ep_c;
    g->castling_rights = mv->prev_castling_rights;
}

static int legal_moves(Game *g, int color, Move *out) {
    int n = 0;
    Move buf[64];
    for (int r = 0; r < 8; r++) for (int c = 0; c < 8; c++) {
        Piece p = g->sq[r][c];
        if (p.kind == EMPTY || p.color != color) continue;
        int m = 0; raw_moves(g, r, c, buf, &m);
        for (int i = 0; i < m; i++) {
            Move mv = buf[i];
            make_move(g, &mv);
            if (!in_check(g, color)) out[n++] = mv;
            undo_move(g, &mv);
        }
    }
    int kr, kc;
    if (find_king(g, color, &kr, &kc) && !g->sq[kr][kc].has_moved) {
        int back = (color == WHITE) ? 7 : 0;
        int opp = opposite_color(color);
        int ks = (color == WHITE) ? CASTLE_WK : CASTLE_BK;
        if (g->castling_rights & ks) {
            Piece rook = g->sq[back][7];
            if (rook.kind == ROOK && !rook.has_moved &&
                g->sq[back][5].kind == EMPTY && g->sq[back][6].kind == EMPTY &&
                !in_check(g, color) && !square_attacked(g, back, 5, opp) && !square_attacked(g, back, 6, opp)) {
                Move m; memset(&m, 0, sizeof(m));
                m.from_r = back; m.from_c = 4; m.to_r = back; m.to_c = 6;
                m.is_castling = true; m.rook_from_col = 7; m.rook_to_col = 5;
                out[n++] = m;
            }
        }
        int qs = (color == WHITE) ? CASTLE_WQ : CASTLE_BQ;
        if (g->castling_rights & qs) {
            Piece rook = g->sq[back][0];
            if (rook.kind == ROOK && !rook.has_moved &&
                g->sq[back][1].kind == EMPTY && g->sq[back][2].kind == EMPTY && g->sq[back][3].kind == EMPTY &&
                !in_check(g, color) && !square_attacked(g, back, 2, opp) && !square_attacked(g, back, 3, opp)) {
                Move m; memset(&m, 0, sizeof(m));
                m.from_r = back; m.from_c = 4; m.to_r = back; m.to_c = 2;
                m.is_castling = true; m.rook_from_col = 0; m.rook_to_col = 3;
                out[n++] = m;
            }
        }
    }
    return n;
}

static bool is_checkmate(Game *g, int color) {
    Move tmp[256];
    return in_check(g, color) && legal_moves(g, color, tmp) == 0;
}
static bool is_stalemate(Game *g, int color) {
    Move tmp[256];
    return !in_check(g, color) && legal_moves(g, color, tmp) == 0;
}

static const char *play_auto(Game *g) {
    int max_moves = 500;
    Move legal[256];
    while (!g->is_over && g->move_count < max_moves) {
        int n = legal_moves(g, g->current_turn, legal);
        if (n == 0) {
            if (in_check(g, g->current_turn)) return (g->current_turn == BLACK) ? "White" : "Black";
            return "Draw";
        }
        int idx = random_int(n);
        Move chosen = legal[idx];
        make_move(g, &chosen);
        g->move_count++;
        g->current_turn = opposite_color(g->current_turn);
        if (is_checkmate(g, g->current_turn)) return (g->current_turn == BLACK) ? "White" : "Black";
        else if (is_stalemate(g, g->current_turn)) return "Draw";
    }
    return "Draw";
}

static void benchmark(int num_games) {
    int white = 0, black = 0, draws = 0;
    printf("Running %d games...\n\n", num_games);
    for (int i = 0; i < num_games; i++) {
        Game g; game_init(&g);
        seed_random((uint64_t)(i * 7919 + 42));
        const char *result = play_auto(&g);
        if (strcmp(result, "White") == 0) { white++; printf("Game %d: White wins\n", i + 1); }
        else if (strcmp(result, "Black") == 0) { black++; printf("Game %d: Black wins\n", i + 1); }
        else { draws++; printf("Game %d: Draw\n", i + 1); }
    }
    printf("\n--- Results (%d games) ---\n", num_games);
    printf("White wins: %d\n", white);
    printf("Black wins: %d\n", black);
    printf("Draws:      %d\n", draws);
}

int main(int argc, char **argv) {
    int bench = 20;
    for (int i = 1; i < argc; i++) {
        if ((strcmp(argv[i], "--benchmark") == 0 || strcmp(argv[i], "-b") == 0) && i + 1 < argc)
            bench = atoi(argv[i + 1]);
    }
    if (bench > 0) benchmark(bench);
    return 0;
}
