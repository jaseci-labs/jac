"""Test fixture for removing unnecessary <> escaping from names.

This fixture contains names with <> that should be removed (not keywords)
and names with <> that should be preserved (actual Jac keywords).
"""

# Regular variable names with unnecessary <> escaping - should be removed
glob <>foo = 1;
glob <>bar = 2;
glob <>myvar = 3;
glob <>count = 4;
glob <>data = 5;

# Jac keywords used as variable names - escaping should be preserved
glob <>node = 10;
glob <>edge = 20;
glob <>walker = 30;

# Object with mixed escaped names
obj TestClass {
    # Unnecessary escaping in has variables - should be removed
    has <>name: str = "test",
        <>value: int = 0,
        <>init: int = 4;

    # Method with unnecessary escaping in parameter name - should be removed
    def process(<>item: str) -> str {
        # Local variable with unnecessary escaping - should be removed
        <>result = self.name + <>item;
        return <>result;
    }
}

# Function with unnecessary escaping - should be removed
def compute(<>input_val: int, <>output_val: int) -> int {
    <>total = <>input_val + <>output_val;
    return <>total;
}
