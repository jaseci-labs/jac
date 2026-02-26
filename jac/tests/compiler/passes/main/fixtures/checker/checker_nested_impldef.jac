# ===================================================================
# Test 1: Simple nested function in impl block
# ===================================================================
def simple_nested -> str;

impl simple_nested -> str {
    def inner -> int {
        return 42;  # Should check against int, not str

    }
    return f"Result: {inner()}";
}

# ===================================================================
# Test 2: Deep nesting
# ===================================================================
def deep_nesting -> str;

impl deep_nesting -> str {
    def level1 -> int {
        def level2 -> float {
            def level3 -> bool {
                return True;  # Should check against bool

            }
            return 3.14 if level3() else 0.0;  # Should check against float

        }
        return int(level2());
    }
    return f"Deep: {level1()}";
}

# ===================================================================
# Test 3: impl block inside function body
# ===================================================================
def outer_with_impl -> str {
    def helper -> int;

    impl helper -> int {
        return 42;  # Should check against int (no nested function)

    }

    return f"Impl in function: {helper()}";  # Should check against str

}
