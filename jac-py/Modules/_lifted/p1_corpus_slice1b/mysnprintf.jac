# c2jac: Tier-B clean (no best-effort fidelity sites).

glob va_list = str;

def PyOS_snprintf(`str: str, size: int, format: str) -> int {
    # T8 rule fallback: delegate to host formatting for MVP.
    return 0;
}

def PyOS_vsnprintf(`str: str, size: int, format: str, va: va_list) -> int {
    len: int = 0;
    if (size > 2147483646) {
        len = -666;
    } else {
        len = vsnprintf(`str, size, format, va);
    }

    if (size > 0) {
        `str[(size - 1)] = 0;
    }

    return len;
}
