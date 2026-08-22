glob va_list = str;

def PyOS_snprintf(`str: str, size: int, format: str) -> int {
    va: va_list = "";
    return PyOS_vsnprintf(`str, size, format, va);
}

def PyOS_vsnprintf(`str: str, size: int, format: str, va: va_list) -> int {
    len: int = 0;
    if (size > 2147483646) {
        len = -666;
    } else {
        len = vsnprintf(`str, size, format, va);
    }

    if (size > 0 and size <= 2147483646) {
        `str[(size - 1)] = 0;
    }

    return len;
}
