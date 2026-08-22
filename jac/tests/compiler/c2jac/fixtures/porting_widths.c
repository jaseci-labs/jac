#include <stddef.h>
#include <stdint.h>
#include <jacport.h>

size_t port_add_size(size_t a, size_t b) {
    return a + b;
}

uint64_t port_widen(uint32_t x) {
    return (uint64_t)x;
}

Py_ssize_t port_ssize(Py_ssize_t n) {
    return n + 1;
}
