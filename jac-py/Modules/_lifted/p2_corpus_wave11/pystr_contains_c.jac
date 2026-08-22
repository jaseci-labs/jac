def pystr_contains_c(hay: str, needle: str) -> int {
    i: int = 0;
    j: int = 0;
    if ((hay == 0) or (needle == 0)) {
        return 0;
    }

    if (needle[0] == 0) {
        return 1;
    }

    i = 0;
    while (hay[i] != 0) {
        j = 0;
        while (
            ((needle[j] != 0) and (hay[(i + j)] != 0))
            and ((hay[(i + j)] & 255) == (needle[j] & 255))
        ) {
            j += 1;
        }

        if (needle[j] == 0) {
            return 1;
        }

        i += 1;
    }

    return 0;
}
