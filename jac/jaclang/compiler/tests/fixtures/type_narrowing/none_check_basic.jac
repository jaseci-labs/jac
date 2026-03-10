"""Test type narrowing for None checks.

Tests:
- x is None
- x is not None
- x == None / x != None
- narrowing in else branch
"""

"""Test 1: Basic is not None narrowing"""
def test_is_not_none(x: int | None) {
    if x is not None {
        # x should be narrowed to int here
        len_ok: int = x.bit_length();
    }
}


"""Test 2: Basic is None narrowing with else"""
def test_is_none_else(x: int | None) {
    if x is None {
        # x should be None here
        none_val: None = x;
    } else {
        # x should be int here
        int_val: int = x;
        len_ok: int = x.bit_length();
    }
}


"""Test 3: x != None narrowing"""
def test_not_equal_none(x: int | None) {
    if x != None {
        # x should be narrowed to int here
        int_val: int = x;
    }
}


"""Test 4: x == None narrowing with else"""
def test_equal_none_else(x: int | None) {
    if x == None {
        # x should be None here
        none_val: None = x;
    } else {
        # x should be int here
        int_val: int = x;
    }
}


"""Test 5: Nested None check with method call"""
def test_none_method_chain(x: str | None) {
    if x is not None {
        # x should be str, can call string methods
        upper_str: str = x.upper();
        len_val: int = len(x);
    }
}


"""Test 6: Multiple variables None check"""
def test_multiple_none_checks(a: int | None, b: str | None) {
    if a is not None {
        int_a: int = a;
        if b is not None {
            str_b: str = b;
        }
    }
}


"""Test 7: Object type narrowing with None"""
obj Animal {
    has name: str;
}

def test_object_none(pet: Animal | None) {
    if pet is not None {
        # pet should be Animal here
        name: str = pet.name;
    }
}


"""Test 8: Return early pattern"""
def test_early_return(x: int | None) -> int {
    if x is None {
        return 0;
    }
    # x should be int here after the guard clause
    return x + 1;
}
