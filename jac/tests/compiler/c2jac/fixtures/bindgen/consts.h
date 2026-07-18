/* Fixture for `jac cbindgen` Phase 1 (named integer constants).
 * Covers: C enum (implicit-sequential + explicit value), typedef'd enum,
 * object-like #define ints (decimal, hex, negative), and the non-int / macro
 * shapes that must be skipped (string, function-like). Self-contained (no
 * #include) so the suite stays portable. */

#define BUF_CAP 256
#define MASK_HEX 0xFF
#define NEG_ONE -1
#define GREETING "hi"        /* string macro — not bound */
#define SQUARE(x) ((x)*(x))  /* function-like macro — not bound */

enum Status { ST_IDLE, ST_BUSY = 5, ST_DONE };
typedef enum { LVL_LO, LVL_HI = 10 } Level;

int cs_classify(enum Status s);
