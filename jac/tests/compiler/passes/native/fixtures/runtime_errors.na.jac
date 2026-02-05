# Runtime error tests for native LLVM IR codegen.
# These tests verify that proper exceptions are raised for
# invalid operations instead of crashing with hardware faults.

# ============================================================
# ZeroDivisionError
# ============================================================

# Test 1: Integer division by zero
def test_int_div_by_zero() -> int {
    result: int = 0;
    try {
        x: int = 10 / 0;
        result = -1;  # Should not reach
    } except ZeroDivisionError {
        result = 1;
    }
    return result;
}

# Test 2: Integer modulo by zero
def test_int_mod_by_zero() -> int {
    result: int = 0;
    try {
        x: int = 10 % 0;
        result = -1;
    } except ZeroDivisionError {
        result = 1;
    }
    return result;
}

# Test 3: Division by zero with variable divisor
def test_div_by_zero_var() -> int {
    result: int = 0;
    d: int = 0;
    try {
        x: int = 42 / d;
        result = -1;
    } except ZeroDivisionError {
        result = 1;
    }
    return result;
}

# Test 4: Float division by zero
def test_float_div_by_zero() -> int {
    result: int = 0;
    try {
        x: float = 10.0 / 0.0;
        result = -1;
    } except ZeroDivisionError {
        result = 1;
    }
    return result;
}

# Test 5: Division by non-zero should NOT raise
def test_div_no_error() -> int {
    result: int = 0;
    try {
        x: int = 10 / 2;
        result = x;  # Should be 5
    } except ZeroDivisionError {
        result = -1;
    }
    return result;
}

# ============================================================
# IndexError
# ============================================================

# Test 6: List index beyond length
def test_list_index_oob() -> int {
    result: int = 0;
    nums: list[int] = [10, 20, 30];
    try {
        x: int = nums[5];
        result = -1;
    } except IndexError {
        result = 1;
    }
    return result;
}

# Test 7: List negative index (out of bounds)
def test_list_negative_index() -> int {
    result: int = 0;
    nums: list[int] = [10, 20, 30];
    try {
        x: int = nums[-1];
        result = -1;
    } except IndexError {
        result = 1;
    }
    return result;
}

# Test 8: List index at exact length (off-by-one)
def test_list_index_at_len() -> int {
    result: int = 0;
    nums: list[int] = [10, 20, 30];
    try {
        x: int = nums[3];  # len is 3, max valid index is 2
        result = -1;
    } except IndexError {
        result = 1;
    }
    return result;
}

# Test 9: List valid index should NOT raise
def test_list_valid_index() -> int {
    result: int = 0;
    nums: list[int] = [10, 20, 30];
    try {
        result = nums[1];  # Should be 20
    } except IndexError {
        result = -1;
    }
    return result;
}

# Test 10: List set out of bounds
def test_list_set_oob() -> int {
    result: int = 0;
    nums: list[int] = [10, 20, 30];
    try {
        nums[10] = 99;
        result = -1;
    } except IndexError {
        result = 1;
    }
    return result;
}

# Test 11: Empty list access
def test_empty_list_access() -> int {
    result: int = 0;
    nums: list[int] = [];
    try {
        x: int = nums[0];
        result = -1;
    } except IndexError {
        result = 1;
    }
    return result;
}

# ============================================================
# KeyError
# ============================================================

# Test 12: Dict access with missing key
def test_dict_missing_key() -> int {
    result: int = 0;
    d: dict[str, int] = {"a": 1, "b": 2};
    try {
        x: int = d["c"];
        result = -1;
    } except KeyError {
        result = 1;
    }
    return result;
}

# Test 13: Dict access with existing key should NOT raise
def test_dict_valid_key() -> int {
    result: int = 0;
    d: dict[str, int] = {"a": 1, "b": 2};
    try {
        result = d["b"];  # Should be 2
    } except KeyError {
        result = -1;
    }
    return result;
}

# Test 14: Dict int key missing
def test_dict_int_missing_key() -> int {
    result: int = 0;
    d: dict[int, int] = {1: 100, 2: 200};
    try {
        x: int = d[99];
        result = -1;
    } except KeyError {
        result = 1;
    }
    return result;
}

# ============================================================
# OverflowError
# ============================================================

# Test 15: i64 addition overflow (MAX + 1)
def test_int_add_overflow() -> int {
    result: int = 0;
    try {
        x: int = 9223372036854775807;  # i64 max
        y: int = x + 1;
        result = -1;
    } except OverflowError {
        result = 1;
    }
    return result;
}

# Test 16: i64 subtraction underflow (MIN - 1)
def test_int_sub_underflow() -> int {
    result: int = 0;
    try {
        x: int = -9223372036854775807 - 1;  # i64 min
        y: int = x - 1;
        result = -1;
    } except OverflowError {
        result = 1;
    }
    return result;
}

# Test 17: i64 multiplication overflow
def test_int_mul_overflow() -> int {
    result: int = 0;
    try {
        x: int = 9223372036854775807;
        y: int = x * 2;
        result = -1;
    } except OverflowError {
        result = 1;
    }
    return result;
}

# Test 18: Non-overflowing arithmetic should NOT raise
def test_int_no_overflow() -> int {
    result: int = 0;
    try {
        x: int = 1000000;
        y: int = x * 1000;  # 1 billion, well within i64
        result = 1;
    } except OverflowError {
        result = -1;
    }
    return result;
}

# ============================================================
# AttributeError (None/null dereference)
# ============================================================
obj SimpleObj {
    has val: int = 42;

    def get_val() -> int {
        return self.val;
    }
}

# Test 19: Field access on None
def test_none_field_access() -> int {
    result: int = 0;
    s: SimpleObj = None;
    try {
        x: int = s.val;
        result = -1;
    } except AttributeError {
        result = 1;
    }
    return result;
}

# Test 20: Method call on None
def test_none_method_call() -> int {
    result: int = 0;
    s: SimpleObj = None;
    try {
        x: int = s.get_val();
        result = -1;
    } except AttributeError {
        result = 1;
    }
    return result;
}

# Test 21: Non-None access should NOT raise
def test_valid_obj_access() -> int {
    result: int = 0;
    s: SimpleObj = SimpleObj();
    try {
        result = s.get_val();  # Should be 42
    } except AttributeError {
        result = -1;
    }
    return result;
}

# ============================================================
# ValueError
# ============================================================

# Test 22: int() with invalid string
def test_int_parse_invalid() -> int {
    result: int = 0;
    try {
        x: int = int("not_a_number");
        result = -1;
    } except ValueError {
        result = 1;
    }
    return result;
}

# Test 23: int() with valid string should NOT raise
def test_int_parse_valid() -> int {
    result: int = 0;
    try {
        x: int = int("123");
        result = x;  # Should be 123
    } except ValueError {
        result = -1;
    }
    return result;
}

# Test 24: int() with empty string
def test_int_parse_empty() -> int {
    result: int = 0;
    try {
        x: int = int("");
        result = -1;
    } except ValueError {
        result = 1;
    }
    return result;
}

# ============================================================
# AssertionError
# ============================================================

# Test 25: Failed assertion
def test_assert_false() -> int {
    result: int = 0;
    try {
        assert 1 == 2;
        result = -1;
    } except AssertionError {
        result = 1;
    }
    return result;
}

# Test 26: Passing assertion should NOT raise
def test_assert_true() -> int {
    result: int = 0;
    try {
        assert 1 == 1;
        result = 1;
    } except AssertionError {
        result = -1;
    }
    return result;
}

# ============================================================
# MemoryError (allocation failure — hard to trigger naturally)
# ============================================================

# Test 27: Normal allocation should NOT raise MemoryError
def test_alloc_ok() -> int {
    result: int = 0;
    try {
        s: SimpleObj = SimpleObj();
        result = 1;
    } except MemoryError {
        result = -1;
    }
    return result;
}

# ============================================================
# Combined / edge cases
# ============================================================

# Test 28: Catch parent Exception type for ZeroDivisionError
def test_catch_base_exception() -> int {
    result: int = 0;
    try {
        x: int = 10 / 0;
        result = -1;
    } except Exception {
        result = 1;
    }
    return result;
}

# Test 29: Multiple runtime errors in sequence
def test_sequential_errors() -> int {
    r1: int = 0;
    r2: int = 0;
    try {
        x: int = 1 / 0;
    } except ZeroDivisionError {
        r1 = 1;
    }
    nums: list[int] = [1, 2, 3];
    try {
        y: int = nums[10];
    } except IndexError {
        r2 = 1;
    }
    return r1 * 10 + r2;  # Should be 11

}

# Test 30: Runtime error in loop
def test_error_in_loop() -> int {
    count: int = 0;
    i: int = 0;
    while i < 5 {
        try {
            x: int = 10 / i;  # Fails when i==0
        } except ZeroDivisionError {
            count = count + 1;
        }
        i = i + 1;
    }
    return count;  # Should be 1 (only i==0 triggers it)

}
