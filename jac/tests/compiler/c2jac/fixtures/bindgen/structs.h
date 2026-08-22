/* Fixture for `jac cbindgen` Phase 3 (struct layout bindings).
 * Exercises: plain named struct, typedef'd anonymous struct, struct-by-value
 * params/returns, struct-pointer params (must remain int), and int fields
 * alongside float fields. Self-contained — no #include required. */

struct Point { int x; int y; };

typedef struct { float r; float g; float b; } Color;

struct Point pt_add(struct Point a, struct Point b);
int pt_dot(struct Point a, struct Point b);
Color color_blend(Color a, Color b, float t);
void pt_translate(struct Point *p, int dx, int dy);
