"""Test file for empty parentheses removal from function declarations."""

# Function with no params and no return type - parens should be removed
def no_params() {
    print("hello");
}

# Function with params - parens should stay
def with_params(x: int) {
    print(x);
}

# Function with no params but with return type - parens should be removed
def no_params_with_return()  -> int {
    return 42;
}

# Function with params and return type - parens should stay
def with_params_and_return(
    x: int
) -> int {
    return x * 2;
}

class MyClass {
    # Method with only self - parens should stay (self is a param)
    def method_with_self(self: MyClass) {
        print("hi");
    }

    # Method with self and other params - parens should stay
    def method_with_params(self: MyClass, a: int, b: int) -> int {
        return a + b;
    }
}

obj Counter {
    has count: int = 0;

    # Method with no params - parens should be removed
    def reset() {
        self.count = 0;
    }

    # Method with params - parens should stay
    def increment(amount: int) {
        self.count += amount;
    }

    # Method with no params but return type - parens should be removed
    def get_count()  -> int {
        return self.count;
    }
}
