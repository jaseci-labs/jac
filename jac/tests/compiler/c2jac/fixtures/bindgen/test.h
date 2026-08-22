/* Minimal fixture for `jac cbindgen` Phase 0 (extern function prototypes).
 * Exercises every primitive width, the const char* string idiom, a byte
 * buffer, a no-arg (void) prototype, an opaque pointer return, and a variadic
 * function. No #include — already preprocessable as-is. */

int tk_add(int a, int b);
unsigned long tk_checksum(const unsigned char *buf, unsigned long n);
double tk_scale(double x, float k);
const char *tk_name(void);
short tk_clamp(short lo, short hi, int v);
void *tk_alloc(unsigned long size);
int tk_logf(const char *fmt, ...);
