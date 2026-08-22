/* P3.2e unicodectype_core extract — Unicode type-flag helpers.
 * Curated from reference/cpython Objects/unicodectype.c.
 */

#include "Python.h"

#include <stddef.h>

#define ALPHA_MASK 0x01
#define DECIMAL_MASK 0x02
#define DIGIT_MASK 0x04
#define LOWER_MASK 0x08
#define LINEBREAK_MASK 0x10
#define SPACE_MASK 0x20
#define TITLE_MASK 0x40
#define UPPER_MASK 0x80
#define XID_START_MASK 0x100
#define XID_CONTINUE_MASK 0x200
#define PRINTABLE_MASK 0x400

int
unicodectype_isalpha_flags(unsigned int flags)
{
    return (flags & ALPHA_MASK) != 0;
}

int
unicodectype_isdigit_flags(unsigned int flags)
{
    return (flags & DIGIT_MASK) != 0;
}

int
unicodectype_isspace_flags(unsigned int flags)
{
    return (flags & SPACE_MASK) != 0;
}

int
unicodectype_isupper_flags(unsigned int flags)
{
    return (flags & UPPER_MASK) != 0;
}

int
unicodectype_islower_flags(unsigned int flags)
{
    return (flags & LOWER_MASK) != 0;
}
