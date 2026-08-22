/* Bindgen via porting LP64 stdint/stddef (no local wrong-width typedefs). */
#include <stdint.h>
#include <stddef.h>

uint64_t port_len(size_t n);
int32_t port_clamp(int32_t v, int32_t lo, int32_t hi);
