"""Test augmented assignment operators: +=, -=, *=, //=, %=."""

def test_add_assign() -> int {
    x: int = 10;
    x += 5;
    return x;
}

def test_sub_assign() -> int {
    x: int = 100;
    x -= 37;
    return x;
}

def test_mul_assign() -> int {
    x: int = 7;
    x *= 6;
    return x;
}

def test_div_assign() -> int {
    x: int = 99;
    x //= 10;
    return x;
}

def test_mod_assign() -> int {
    x: int = 17;
    x %= 5;
    return x;
}

def test_chained_aug() -> int {
    x: int = 1;
    x += 2;
    x *= 3;
    x -= 1;
    return x;
}

def test_aug_in_while() -> int {
    total: int = 0;
    i: int = 0;
    while i < 10 {
        total += i;
        i += 1;
    }
    return total;
}

def test_aug_in_for() -> int {
    total: int = 0;
    for i in range(10) {
        total += i;
    }
    return total;
}

def test_aug_conditional() -> int {
    even_sum: int = 0;
    odd_sum: int = 0;
    for i in range(10) {
        if i % 2 == 0 {
            even_sum += i;
        } else {
            odd_sum += i;
        }
    }
    return even_sum * 100 + odd_sum;
}

def test_aug_nested_loops() -> int {
    total: int = 0;
    i: int = 0;
    while i < 5 {
        j: int = 0;
        while j < 5 {
            total += 1;
            j += 1;
        }
        i += 1;
    }
    return total;
}

def test_aug_float_add() -> float {
    x: float = 1.5;
    x += 2.5;
    return x;
}

def test_aug_float_mul() -> float {
    x: float = 3.0;
    x *= 2.5;
    return x;
}

def test_count_primes() -> int {
    count: int = 0;
    num: int = 2;
    while count < 10 {
        is_p: bool = True;
        d: int = 2;
        while d * d <= num {
            if num % d == 0 {
                is_p = False;
                break;
            }
            d += 1;
        }
        if is_p {
            count += 1;
        }
        num += 1;
    }
    return num - 1;
}

def test_forever_break() -> int {
    total: int = 0;
    i: int = 0;
    forever {
        total += i;
        i += 1;
        if i >= 10 {
            break;
        }
    }
    return total;
}

def test_forever_continue() -> int {
    total: int = 0;
    i: int = 0;
    forever {
        i += 1;
        if i > 10 {
            break;
        }
        if i % 2 == 1 {
            continue;
        }
        total += i;
    }
    return total;
}


def test_list_iadd_alias() -> int {
    xs: list[int] = [1, 2];
    alias = xs;
    xs += [3];
    return len(xs) * 100 + len(alias);
}

def test_list_imul_alias() -> int {
    xs: list[int] = [1, 2];
    alias = xs;
    xs *= 2;
    return len(xs) * 100 + len(alias);
}


def test_list_imul_zero_reuse() -> int {
    ys: list[str] = ["aa", "bb", "cc"];
    ys *= 0;
    if len(ys) != 0 {
        return -1;
    }
    ys.append("dd");
    return len(ys) * 100 + len(ys[0]);
}

def test_list_imul_empty_huge() -> int {
    zs: list[int] = [];
    zs *= 1000000000;
    return len(zs);
}

def test_list_imul_str_nine() -> int {
    ws: list[str] = ["xy"];
    ws *= 9;
    total: int = 0;
    for w in ws {
        total += len(w);
    }
    return total * 100 + len(ws);
}
