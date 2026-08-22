/* Header-free extract from Python/codecs.c + pystrhex.c (single-byte hexlify). */

static const char _hexdigits[] = "0123456789abcdef";

unsigned int
strhex_pack_byte(unsigned char value)
{
    unsigned char hi;
    unsigned char lo;
    hi = (unsigned char)_hexdigits[value >> 4];
    lo = (unsigned char)_hexdigits[value & 0x0f];
    return ((unsigned int)hi << 8) | (unsigned int)lo;
}
