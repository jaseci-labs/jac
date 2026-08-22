/* P3.2e bytes_methods_core extract — byte character class helpers.
 * Curated from reference/cpython Objects/bytes_methods.c.
 */

#include "Python.h"

#include <stddef.h>

int
bytes_isupper_byte(int c)
{
    return c >= 'A' && c <= 'Z';
}

int
bytes_islower_byte(int c)
{
    return c >= 'a' && c <= 'z';
}

int
bytes_isdigit_byte(int c)
{
    return c >= '0' && c <= '9';
}

int
bytes_isspace_byte(int c)
{
    return c == ' ' || c == '\t' || c == '\n' || c == '\r'
        || c == '\f' || c == '\v';
}

int
bytes_toupper_byte(int c)
{
    if (bytes_islower_byte(c)) {
        return c - ('a' - 'A');
    }
    return c;
}

int
bytes_tolower_byte(int c)
{
    if (bytes_isupper_byte(c)) {
        return c + ('a' - 'A');
    }
    return c;
}
