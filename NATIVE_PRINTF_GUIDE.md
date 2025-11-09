# Adding Native Printf Support to Jac LLVM Backend

## Current Status

The LLVM backend **does not yet support** function calls, including printf. This guide explains how to add this functionality.

## What's Needed

To support native printf, we need to implement:

1. ✅ External function declarations (created: `extern_funcs.py`)
2. ❌ String literal support in the parser/AST
3. ❌ Function call expression compilation
4. ❌ Integration with `LlvmIrGenPass`

## Quick Implementation Roadmap

### Step 1: Add String Literal Support

**Location**: `llvmir_gen_pass.py`, in `_compile_expr()` method

```python
def _compile_expr(self, expr: uni.Expr) -> Optional[_ir.Value]:
    # ... existing code ...

    # Add string support
    if isinstance(expr, uni.String):
        return self._create_string_literal(expr.lit_value)

    # ... rest of code ...

def _create_string_literal(self, value: str) -> _ir.Value:
    """Create a string literal constant."""
    if not hasattr(self, '_extern_funcs'):
        from .llvmir.extern_funcs import ExternalFunctions
        self._extern_funcs = ExternalFunctions(self._module)

    from .llvmir.extern_funcs import create_string_constant
    return create_string_constant(
        self._module,
        self._builder,
        value,
        name=f"str_{len(value)}"
    )
```

### Step 2: Add Function Call Support

**Location**: `llvmir_gen_pass.py`, in `_compile_expr()` method

```python
def _compile_expr(self, expr: uni.Expr) -> Optional[_ir.Value]:
    # ... existing code ...

    # Add function call support
    if isinstance(expr, uni.FunctionCall):
        return self._compile_function_call(expr)

    # ... rest of code ...

def _compile_function_call(self, node: uni.FunctionCall) -> Optional[_ir.Value]:
    """Compile a function call expression."""
    if not isinstance(node.target, uni.Name):
        self.log_error("Only simple function calls are supported", node_override=node)
        return None

    func_name = node.target.value

    # Check if it's an external function
    if func_name == "printf":
        return self._compile_printf_call(node)

    # Check if it's a user-defined function
    # TODO: Add support for calling other Jac functions

    self.log_error(f"Function '{func_name}' not found", node_override=node)
    return None

def _compile_printf_call(self, node: uni.FunctionCall) -> Optional[_ir.Value]:
    """Compile a printf function call."""
    if not hasattr(self, '_extern_funcs'):
        from .llvmir.extern_funcs import ExternalFunctions
        self._extern_funcs = ExternalFunctions(self._module)

    # Declare printf if not already declared
    printf_func = self._extern_funcs.declare_printf()

    # Compile arguments
    args = []
    if node.params:
        for arg in node.params.items:
            compiled_arg = self._compile_expr(arg)
            if compiled_arg is None:
                return None
            args.append(compiled_arg)

    if len(args) < 1:
        self.log_error("printf requires at least a format string", node_override=node)
        return None

    # Call printf
    return self._builder.call(printf_func, args, name="printf_result")
```

### Step 3: Example Usage (Once Implemented)

```jac
"""Native printf example"""

def hello_world() -> int {
    printf("Hello, World!\n");
    return 0;
}

def print_number(x: int) -> int {
    printf("The number is: %d\n", x);
    return x;
}

def print_calculation(a: int, b: int) -> int {
    result: int = a + b;
    printf("Result of %d + %d = %d\n", a, b, result);
    return result;
}

def print_float(x: float) -> int {
    printf("Float value: %f\n", x);
    return 0;
}
```

**Execution**:
```bash
jac native examples/printf_test.jac --entry hello_world
# Output: Hello, World!

jac native examples/printf_test.jac --entry print_number -- 42
# Output: The number is: 42

jac native examples/printf_test.jac --entry print_calculation -- 10 5
# Output: Result of 10 + 5 = 15
```

## Alternative: Use `puts` for Simple Strings

If you only need to print strings without formatting, `puts` is simpler:

```python
def _compile_puts_call(self, node: uni.FunctionCall) -> Optional[_ir.Value]:
    """Compile a puts function call (simpler than printf)."""
    if not hasattr(self, '_extern_funcs'):
        from .llvmir.extern_funcs import ExternalFunctions
        self._extern_funcs = ExternalFunctions(self._module)

    puts_func = self._extern_funcs.declare_puts()

    # Compile the string argument
    if not node.params or len(node.params.items) != 1:
        self.log_error("puts requires exactly one string argument", node_override=node)
        return None

    string_arg = self._compile_expr(node.params.items[0])
    if string_arg is None:
        return None

    return self._builder.call(puts_func, [string_arg], name="puts_result")
```

## Workaround: Use Python Print for Now

Until function calls are implemented, you can use the Python runtime:

```jac
def debug_value(x: int) -> int {
    # This will use Python's print when running with `jac run`
    print(f"Debug: {x}");
    return x;
}
```

Then run with:
```bash
jac run examples/debug.jac  # Uses Python print
```

## Implementation Priority

For a minimal viable printf support:

1. **High Priority** (Essential):
   - [ ] String literal support in `_compile_expr`
   - [ ] Basic function call support
   - [ ] External function declaration integration
   - [ ] printf declaration and calling

2. **Medium Priority** (Nice to have):
   - [ ] Support for other libc functions (puts, malloc, free)
   - [ ] Type checking for printf format strings
   - [ ] Better error messages

3. **Low Priority** (Future):
   - [ ] Calling user-defined Jac functions
   - [ ] Function pointers
   - [ ] Variadic Jac functions

## Testing Printf Support

Once implemented, add tests:

```python
# In test_llvm_ir.py

def test_native_printf(self) -> None:
    """Test that printf works in native code."""
    from jaclang.cli import cli
    import subprocess

    # Capture stdout from native execution
    result = subprocess.run(
        ["jac", "native", self.fixture_abs_path("native_printf.jac"),
         "--entry", "hello_world"],
        capture_output=True,
        text=True
    )

    self.assertIn("Hello, World!", result.stdout)

def test_native_printf_with_args(self) -> None:
    """Test printf with format arguments."""
    result = subprocess.run(
        ["jac", "native", self.fixture_abs_path("native_printf.jac"),
         "--entry", "print_number", "--", "42"],
        capture_output=True,
        text=True
    )

    self.assertIn("The number is: 42", result.stdout)
```

## LLVM IR Example

Here's what the generated LLVM IR should look like:

```llvm
@.str = private unnamed_addr constant [15 x i8] c"Hello, World!\0A\00"

declare i32 @printf(i8*, ...)

define i32 @hello_world() {
entry:
  %0 = getelementptr [15 x i8], [15 x i8]* @.str, i32 0, i32 0
  %1 = call i32 (i8*, ...) @printf(i8* %0)
  ret i32 0
}
```

## Files Created

I've created the infrastructure for you:

1. **[extern_funcs.py](jac/jaclang/compiler/passes/main/llvmir/extern_funcs.py)** - External function declarations
   - `ExternalFunctions` class
   - `declare_printf()` method
   - `declare_puts()` method
   - `create_string_constant()` helper

2. **[native_printf.jac](jac/jaclang/tests/fixtures/native_printf.jac)** - Example test fixture

## Next Steps

To complete the implementation:

1. Study how `uni.FunctionCall` and `uni.String` nodes work in the AST
2. Add string literal handling to `_compile_expr`
3. Add function call handling to `_compile_expr`
4. Integrate `ExternalFunctions` into `LlvmIrGenPass.enter_module`
5. Write tests
6. Test with actual printf calls

Would you like me to implement the full function call support right now?
