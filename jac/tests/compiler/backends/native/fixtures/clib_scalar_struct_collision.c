#include <stdint.h>

typedef struct { uint8_t value; } ByteBox;
typedef struct { uint16_t value; } ShortBox;
typedef struct { uint8_t r, g, b, a; } Color;
typedef struct { uint32_t value; } WordBox;
typedef struct { uint64_t value; } LongBox;

int8_t scalar8(void) { return -7; }
int16_t scalar16(void) { return -1234; }
int32_t scalar32(void) { return -123456; }
int64_t scalar64(void) { return -12345678901LL; }
uint32_t unsigned32(void) { return UINT32_MAX; }
Color color_value(void) { return (Color){11, 22, 33, 44}; }
WordBox word_value(void) { return (WordBox){987654}; }
LongBox long_value(void) { return (LongBox){12345678901ULL}; }
