# c2jac: 1 best-effort site lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L19 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied

glob Py_ssize_t = int;


def itertools_count_next_fast(cnt: object, out: object) -> int {
    if (cnt == 9223372036854775807) {
        return -1;
    }

    out = cnt;
    cnt = cnt + 1;
    return 0;
}


def itertools_cycle_advance(index: int, saved_len: int) -> int {
    next: int = index + 1;
    if (next >= saved_len) {
        next = 0;
    }

    return next;
}


def itertools_repeat_take(cnt: object) -> int {
    if (cnt == 0) {
        return 0;
    }

    if (cnt > 0) {
        cnt = cnt - 1;
    }

    return 1;
}


def itertools_chain_scan(remaining: object, nsrc: int, active: object) -> int {
    if (active < 0) {
        active = 0;
    }

    while (active < nsrc) {
        if (remaining[active] > 0) {
            remaining[active] = remaining[active] - 1;
            return active;
        }

        active = active + 1;
    }

    return -1;
}


def itertools_product_advance(indices: object, sizes: object, npools: int) -> int {
    i: int = npools - 1;
    while (i >= 0) {
        indices[i] = indices[i] + 1;
        if (indices[i] < sizes[i]) {
            return 0;
        }

        indices[i] = 0;
        i = i - 1;
    }

    return -1;
}


def itertools_combinations_scan(indices: object, n: int, r: int) -> int {
    i: int = r - 1;
    j: int = 0;
    while ((i >= 0) and (indices[i] == ((i + n) - r))) {
        i = i - 1;
    }

    if (i < 0) {
        return -1;
    }

    indices[i] = indices[i] + 1;
    for j = i + 1 while j < r with j += 1 {
        indices[j] = indices[(j - 1)] + 1;
    }

    return i;
}


def itertools_cwr_scan(indices: object, n: int, r: int) -> int {
    i: int = r - 1;
    j: int = 0;
    index: int = 0;
    while ((i >= 0) and (indices[i] == (n - 1))) {
        i = i - 1;
    }

    if (i < 0) {
        return -1;
    }

    index = indices[i] + 1;
    for j = i while j < r with j += 1 {
        indices[j] = index;
    }

    return i;
}


def itertools_permutations_step(
    indices: object, cycles: object, n: int, r: int
) -> int {
    i: int = r - 1;
    j: int = 0;
    index: int = 0;
    while (i >= 0) {
        cycles[i] = cycles[i] - 1;
        if (cycles[i] == 0) {
            index = indices[i];
            for j = i while j < (n - 1) with j += 1 {
                indices[j] = indices[(j + 1)];
            }

            indices[(n - 1)] = index;
            cycles[i] = n - i;
            i = i - 1;
        } else {
            j = cycles[i];
            index = indices[i];
            indices[i] = indices[(n - j)];
            indices[(n - j)] = index;
            break;
        }
    }

    if (i < 0) {
        return -1;
    }

    return i;
}
