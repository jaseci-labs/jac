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
