"""Intensive test for comment preservation during auto-lint normalize operations.

This file tests various scenarios where normalize() is called and comments
might be lost or misplaced:
1. Consecutive has statement combining
2. Consecutive glob statement combining
3. @staticmethod -> static conversion
4. __init__/__post_init__ -> init/postinit conversion
5. with entry block transformation
6. hasattr() -> null-safe access
7. Ternary -> or simplification
8. Angle bracket escape removal
"""

# Comment before first glob
glob x = 1;  # Inline comment on first glob
# Comment between glob statements
glob y = 2;  # Inline comment on second glob
# Comment before third glob
glob z = 3;  # Inline comment on third glob

# Different access modifier - should not combine
glob : priv private_var = 100;  # Inline on private glob

# Comment before obj definition
obj Calculator {
    # Comment before first has
    has value: int;  # Inline comment on value
    # Comment between has statements - CRITICAL: may be lost during combine
    has name: str;  # Inline comment on name
    # Comment before third has
    has count: int = 0;  # Inline comment on count
    # Different modifier - should stay separate
    has : priv secret: str;  # Inline on private has
    # Static has fields with comments
    static has instance_count: int = 0;  # Inline on static has
    # Between static has
    static has version: str = "1.0";  # Second static has inline

    # Comment before method declaration
    def add(a: int, b: int) -> int;  # Inline on method decl

    # Comment before staticmethod
    @staticmethod  # Comment on decorator
    def helper -> None;  # Inline on helper decl


    # Comment before init
    def __init__(self: Calculator, val: int) -> None;  # Inline on init decl


    # Nested obj with comments
    obj InnerClass {
        # Comment in inner obj has
        has inner_val: int;  # Inline inner has
        # Second inner has comment
        has inner_name: str;  # Second inline inner has
    }
}

# Implementation comments
impl Calculator.add(a: int, b: int) -> int {
    # Comment inside impl body
    return a + b;  # Inline return comment

}

# Comment on staticmethod impl
@ staticmethod  # Decorator comment on impl
impl Calculator.helper -> None {
    # Comment inside helper
    print("helper");  # Inline print comment
}

# Comment on init impl
impl Calculator.__init__(self: Calculator, val: int) -> None {
    # Comment on self assignment
    self.value = val;  # Inline assignment
    # Comment after init body
}

# Enum with consecutive assignments and comments
enum Color {
    RED = 1,  # Inline on RED
    # Comment before GREEN
    GREEN = 2,  # Inline on GREEN
    # Comment before BLUE
    BLUE = 3,  # Inline on BLUE
}

# Test hasattr conversion with comments
obj NullSafeTest {
    has data: dict | None;
    has obj: any | None;

    def check_attr -> any {
        # Comment before hasattr usage
        if hasattr(self.obj, "value") {  # Inline on if hasattr

            # Comment inside if block
            return self.obj.value;  # Return comment

        }
        # Comment after if
        return None;  # Inline on return None

    }

    def check_with_default -> any {
        # Comment before ternary with hasattr
        result = self.obj.attr if hasattr(self.obj, "attr") else "default";  # Inline on ternary
        # Comment after assignment
        return result;  # Return result comment

    }
}

# Test ternary to or simplification with comments
obj TernaryTest {
    has val: int | None;

    def get_or_default -> int {
        # Comment before ternary that should become or
        x = self.val if self.val else 0;  # Inline on ternary
        # Comment after ternary
        return x;  # Return comment

    }

    def nested_ternary -> int {
        # Comment on nested ternary
        a = self.val;  # Inline a
        # Comment between
        b = a if a else (self.val if self.val else 0);  # Nested ternary inline
        # After nested
        return b;  # Return b

    }
}

# Test with entry block transformation
with entry {
    # Comment at start of entry
    entry_x = 10;  # Inline on x
    # Comment between statements
    entry_y = 20;  # Inline on y

    # Comment before print
    print(entry_x + entry_y);  # Inline on print

    # Comment before function def inside entry
    def helper_fn {
        # Inside helper
        return 42;  # Return 42 comment

    }

    # Comment after function
    result = helper_fn();  # Inline on result

    # Assignment that should become glob
    module_level = 100;  # This should become glob with comment
}

# Test angle bracket escaped names with comments
obj KeywordEscapeTest {
    # Comment before escaped name
    has <>type_name: str;  # Inline on escaped name
    # Comment between
    has <>value_name: str;  # Second escaped inline

    # Method with escaped param
    def process(<>input: str) -> str {  # Inline on method with escaped param
        # Comment inside
        return <>input;  # Return escaped

    }
}

# Test multiple has statements with type annotations and defaults
obj ComplexHasTest {
    # Comment block before complex has
    # This is a multi-line comment
    # describing the fields below
    has field1: int = 1;  # First field inline
    # Single comment between
    has field2: str = "test";  # Second field inline
    # Another comment
    # Multi-line again
    has field3: list[int] = [];  # Third field inline
    # Comment before different access
    has : priv private1: int = 0;  # Private field inline
    # Between private fields
    has : priv private2: str = "";  # Second private inline
}

# Test static vs non-static has - should not combine
obj StaticVsNonStaticTest {
    # Comment on static has
    static has static1: int = 10;  # Inline static
    # Between static has
    static has static2: str = "static";  # Second static inline
    # Regular has after static - should not combine
    has mutable: int = 0;  # Mutable inline
}

# Test impl signature mismatch with comments
obj SignatureTest {
    def method1(a: int, b: str, c: float) -> bool;  # Declaration comment

    def method2(x: int) -> int;  # Second decl comment

}

# Impl with same signature
impl SignatureTest.method1(a: int, b: str, c: float) -> bool {
    # Comment inside method1
    return True;  # Return comment

}

impl SignatureTest.method2(x: int) -> int {
    # Comment inside method2
    return x * 2;  # Return double

}

# Test empty parens removal with comments
obj EmptyParensTest {
    def no_params()  -> None;  # Declaration with empty parens

    def also_no_params()  -> int;  # Another empty parens

    def really_no_params_no_return();  # No params no return

}

impl EmptyParensTest.no_params()  -> None {
    # Inside no_params
    print("no params");  # Print comment
}

impl EmptyParensTest.also_no_params()  -> int {
    # Inside also_no_params
    return 42;  # Return answer

}

impl EmptyParensTest.really_no_params_no_return() {
    # Inside really_no_params_no_return
    print("done");  # Done comment
}

# Test import inside code block
obj ImportInsideCode {
    def do_import -> None {
        # Comment before import
        import from os { path }
        ;  # Inline on import
        # Comment after import
        print(path);  # Print path comment
    }
}
# Final comment at end of file
