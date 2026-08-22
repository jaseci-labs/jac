# P3.2e — Unicode type-flag helpers.
# Lift: Objects/_lifted/unicodectype_core.jac

glob ALPHA_MASK: int = 0x01,
     DIGIT_MASK: int = 0x04,
     LOWER_MASK: int = 0x08,
     SPACE_MASK: int = 0x20,
     UPPER_MASK: int = 0x80;

def unicodectype_isalpha_flags(flags: int) -> bool {
    return (flags & ALPHA_MASK) != 0;
}

def unicodectype_isdigit_flags(flags: int) -> bool {
    return (flags & DIGIT_MASK) != 0;
}

def unicodectype_isspace_flags(flags: int) -> bool {
    return (flags & SPACE_MASK) != 0;
}

def unicodectype_isupper_flags(flags: int) -> bool {
    return (flags & UPPER_MASK) != 0;
}

def unicodectype_islower_flags(flags: int) -> bool {
    return (flags & LOWER_MASK) != 0;
}
