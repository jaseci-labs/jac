# LLVM Code Generation Usage Guide

This guide demonstrates how to use the LLVM IR code generation features in Jac.

## Installation

First, install the required dependency:

```bash
pip install llvmlite
```

## Quick Start Examples

### 1. Viewing LLVM IR with `jac tool ir`

View the raw LLVM IR generated from your Jac code:

```bash
jac tool ir llvmir examples/math.jac
```

**Example Jac Code** (`examples/math.jac`):
```jac
def add(a: int, b: int) -> int {
    result = a + b;
    return result;
}

def multiply(x: float, y: float) -> float {
    return x * y;
}
```

**Output**:
```llvm
; ModuleID = 'examples_math'
source_filename = "examples_math"
target triple = "x86_64-unknown-linux-gnu"

define i64 @add(i64 %a, i64 %b) {
entry:
  %a1 = alloca i64
  store i64 %a, i64* %a1
  %b2 = alloca i64
  store i64 %b, i64* %b2
  %result = alloca i64
  %a3 = load i64, i64* %a1
  %b4 = load i64, i64* %b2
  %addtmp = add i64 %a3, %b4
  store i64 %addtmp, i64* %result
  %result5 = load i64, i64* %result
  ret i64 %result5
}

define double @multiply(double %x, double %y) {
entry:
  %x1 = alloca double
  store double %x, double* %x1
  %y2 = alloca double
  store double %y, double* %y2
  %x3 = load double, double* %x1
  %y4 = load double, double* %y2
  %multmp = fmul double %x3, %y4
  ret double %multmp
}
```

### 2. Viewing Optimized LLVM IR

View LLVM IR with -O2 optimizations applied:

```bash
jac tool ir llvmir-opt examples/math.jac
```

**Optimized Output**:
```llvm
define i64 @add(i64 %a, i64 %b) {
entry:
  %addtmp = add i64 %a, %b
  ret i64 %addtmp
}

define double @multiply(double %x, double %y) {
entry:
  %multmp = fmul double %x, %y
  ret double %multmp
}
```

Notice how the optimizer removes unnecessary allocas and loads!

### 3. Viewing Native Assembly Code

Generate assembly code for your target platform:

```bash
jac tool ir asm examples/math.jac
```

**Example Output** (x86-64):
```asm
	.text
	.file	"examples_math"
	.globl	add
	.p2align	4, 0x90
	.type	add,@function
add:
	.cfi_startproc
	leaq	(%rdi,%rsi), %rax
	retq
.Lfunc_end0:
	.size	add, .Lfunc_end0-add
	.cfi_endproc

	.globl	multiply
	.p2align	4, 0x90
	.type	multiply,@function
multiply:
	.cfi_startproc
	mulsd	%xmm1, %xmm0
	retq
.Lfunc_end1:
	.size	multiply, .Lfunc_end1-multiply
	.cfi_endproc
```

### 4. Running Code Natively with JIT Compilation

Execute Jac code natively via LLVM's MCJIT compiler:

```bash
# Basic execution
jac native examples/math.jac --entry add -- 10 5
# Output: 15

# With IR dump
jac native examples/math.jac --entry add --dump-ir -- 10 5

# With optimized IR dump
jac native examples/math.jac --entry add --dump-ir-opt -- 10 5

# With assembly dump
jac native examples/math.jac --entry multiply --dump-asm -- 3.5 2.0
```

### 5. Type Coercion Example

**Code** (`examples/coercion.jac`):
```jac
def int_to_float(x: int) -> float {
    result: float = x + 2.5;
    return result;
}

def mixed_math(a: int, b: float) -> float {
    return a * b + 10.0;
}
```

**Execution**:
```bash
jac native examples/coercion.jac --entry int_to_float -- 5
# Output: 7.5

jac native examples/coercion.jac --entry mixed_math -- 3 4.0
# Output: 22.0
```

**LLVM IR** (showing type coercion):
```bash
jac tool ir llvmir examples/coercion.jac
```

Shows `sitofp` (signed int to float) instructions for type conversions.

### 6. Comparison Operations

**Code** (`examples/compare.jac`):
```jac
def is_greater(a: int, b: int) -> bool {
    return a > b;
}

def float_equals(x: float, y: float) -> bool {
    return x == y;
}
```

**Execution**:
```bash
jac native examples/compare.jac --entry is_greater -- 10 5
# Output: 1  (true)

jac native examples/compare.jac --entry is_greater -- 3 8
# Output: 0  (false)
```

## Programmatic API

### Using JacProgram

```python
from jaclang.compiler.program import JacProgram

# Compile Jac to LLVM IR
prog = JacProgram()
module = prog.compile_to_llvm("examples/math.jac")

# Access the IR
llvm_ir = module.gen.llvm_ir
print(llvm_ir)

# Access metadata
metadata = module.gen.llvm_metadata
print(f"Functions: {list(metadata.keys())}")
print(f"add signature: {metadata['add']}")
# Output: {'return': 'i64', 'args': ['i64', 'i64']}
```

### Using Type-Safe Components

```python
from jaclang.compiler.passes.main.llvmir import TypeMapper, AssemblyGenerator

# Type mapping
mapper = TypeMapper()
llvm_int_type = mapper.map_jac_to_llvm("int")
llvm_float_type = mapper.map_jac_to_llvm("float")

# Assembly generation
asm_gen = AssemblyGenerator()
asm_code = asm_gen.generate(
    llvm_ir_string,
    target_triple="x86_64-unknown-linux-gnu",
    optimization_level=2
)
print(asm_code.decode('utf-8'))
```

### Using llvmlite Directly

```python
import llvmlite.binding as llvm
from jaclang.compiler.program import JacProgram

# Compile to LLVM IR
prog = JacProgram()
module = prog.compile_to_llvm("examples/math.jac")

# Initialize LLVM
llvm.initialize()
llvm.initialize_native_target()
llvm.initialize_native_asmprinter()

# Parse and verify
llvm_module = llvm.parse_assembly(module.gen.llvm_ir)
llvm_module.verify()

# Create JIT execution engine
target = llvm.Target.from_default_triple()
target_machine = target.create_target_machine()
engine = llvm.create_mcjit_compiler(llvm_module, target_machine)

# Get function and call it
func_ptr = engine.get_function_address("add")
import ctypes
add_func = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64, ctypes.c_int64)(func_ptr)
result = add_func(10, 5)
print(f"Result: {result}")  # Output: Result: 15
```

## Supported Features

### Data Types
- ✅ `int` (i64)
- ✅ `float` (double/f64)
- ✅ `bool` (i1)
- ✅ `void`
- ✅ Type coercion (int ↔ float)

### Operations
- ✅ Arithmetic: `+`, `-`, `*`, `/`
- ✅ Comparisons: `==`, `!=`, `<`, `>`, `<=`, `>=`
- ✅ Unary: `+`, `-`, `not`
- ✅ Variable assignments
- ✅ Return statements

### Function Types
- ✅ Plain `def` functions
- ❌ Methods (not yet supported)
- ❌ Async functions (not yet supported)
- ❌ Variadic parameters (not yet supported)

### Control Flow
- ❌ if/else (not yet supported)
- ❌ while loops (not yet supported)
- ❌ for loops (not yet supported)

## Command Reference

### `jac tool ir`

```bash
# LLVM IR (unoptimized)
jac tool ir llvmir <file.jac>

# LLVM IR (optimized)
jac tool ir llvmir-opt <file.jac>

# Native assembly
jac tool ir asm <file.jac>
```

### `jac native`

```bash
jac native <file.jac> [OPTIONS] [-- ARGS...]

Options:
  --entry TEXT         Entry function to execute (default: main)
  --dump-ir           Print LLVM IR before execution
  --dump-ir-opt       Print optimized LLVM IR before execution
  --dump-asm          Print assembly code before execution

Arguments:
  --                  Separator for function arguments
  ARGS                Arguments passed to the entry function
```

## Performance Comparison

### Python Execution
```bash
time jac run examples/math.jac
# Overhead: Python interpreter + Jac runtime
```

### Native Execution
```bash
time jac native examples/math.jac --entry fibonacci -- 35
# Direct machine code execution via LLVM JIT
# Typically 10-100x faster for numeric computations
```

## Debugging

### View All Output Stages

```bash
# Complete pipeline visualization
jac native examples/math.jac --entry add \
  --dump-ir \
  --dump-ir-opt \
  --dump-asm \
  -- 10 5
```

This will show:
1. Unoptimized LLVM IR
2. Optimized LLVM IR (-O2)
3. Native assembly code
4. Execution result

### Error Handling

If your code uses unsupported features:

```jac
def bad_func(x: int, *args) -> int {  # Variadic not supported
    return x;
}
```

```bash
$ jac native examples/bad.jac --entry bad_func -- 5
Error: Variadic parameters are not yet supported by the LLVM backend.
```

## Architecture Overview

The LLVM code generation follows this pipeline:

```
Jac Source (.jac)
    ↓
Jac Parser
    ↓
Jac AST (unitree)
    ↓
Semantic Analysis
    ↓
LlvmIrGenPass
    ↓
LLVM IR Module
    ↓
┌─────────┬──────────┬─────────┐
│         │          │         │
Optimizer  JIT        Assembly
│         │          │         │
-O2 IR    MCJIT      .s file
```

## Best Practices

1. **Use type annotations**: LLVM backend requires explicit types
   ```jac
   def good(x: int) -> int { return x; }  // ✅ Good
   def bad(x) { return x; }               // ❌ Won't work
   ```

2. **Start simple**: Test with arithmetic before complex operations

3. **Check IR**: Use `--dump-ir` to understand code generation

4. **Profile**: Use `--dump-asm` to see actual machine code

5. **Optimize**: Use `llvmir-opt` to see optimization opportunities

## Common Issues

### Issue: "llvmlite is required"
**Solution**: `pip install llvmlite`

### Issue: "Entry 'xyz' not found"
**Solution**: Check function name and ensure it's a plain `def` function

### Issue: "Variadic parameters not supported"
**Solution**: Remove `*args` and `**kwargs` from function signature

### Issue: Type mismatch errors
**Solution**: Add explicit type annotations to all variables and parameters

## Future Enhancements

Planned features (see [LLVM_ARCHITECTURE_ANALYSIS.md](LLVM_ARCHITECTURE_ANALYSIS.md)):

1. Control flow (if/else, loops)
2. Function calls
3. Arrays and strings
4. Object-oriented features
5. Advanced optimizations
6. Multiple target architectures

## References

- [LLVM_ARCHITECTURE_ANALYSIS.md](LLVM_ARCHITECTURE_ANALYSIS.md) - Detailed architecture
- [llvmlite Documentation](https://llvmlite.readthedocs.io/)
- [LLVM Language Reference](https://llvm.org/docs/LangRef.html)
