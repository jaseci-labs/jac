/* Fixture for `jac cbindgen` Phase 2 (fixed-width + typedef scalar resolution).
 * Self-contained (no #include) so the fixed-width NAME map and the same-TU
 * typedef table are exercised without depending on whether pycparser's fake
 * libc headers are installed. The `uint32_t` typedef is deliberately the WRONG
 * width (unsigned long, i.e. 64-bit) to prove the name map (u32) wins over
 * resolving the alias. `real_t` is a genuine user alias resolved via the map. */

typedef unsigned long uint32_t;   /* deliberately wrong width — name map must win */
typedef unsigned long size_t;
typedef long          ssize_t;
typedef unsigned char uint8_t;
typedef double        real_t;     /* user alias → resolves through the typedef map */

uint32_t si_hash(const uint8_t *data, size_t n);
ssize_t  si_read(int fd, uint8_t *buf, size_t n);
real_t   si_scale(real_t x, real_t k);
