"""Test module that imports TypeScript/JavaScript modules (for client code)."""

# Use 'cl import' for string literal imports (JS/TS files)
cl import from ".utils.ts" {
    greet,
    add,
    Calculator,
    VERSION
}
cl import from ".component.js" { Component, theme, render }

# Test importing constants
glob ts_version = VERSION;

# Test importing functions
def test_ts_functions() {
    result = greet("World");
    sum_ = add(1, 2);
}

# Test importing classes
def test_ts_classes() {
    calc = Calculator(10);
    comp = Component("MyComponent");
}

with entry {
    test_ts_functions();
    test_ts_classes();
}
