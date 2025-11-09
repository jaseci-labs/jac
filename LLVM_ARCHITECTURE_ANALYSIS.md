# LLVM IR Code Generation Architecture Analysis

## Executive Summary

This document provides a comprehensive analysis of the LLVM IR code generation integration in the `llvmir_for_fun` branch and proposes architectural improvements to create a production-grade, type-safe implementation.

## Current Architecture Overview

### 1. Core Components

#### 1.1 LlvmIrGenPass ([llvmir_gen_pass.py](jac/jaclang/compiler/passes/main/llvmir_gen_pass.py))
- **Purpose**: AST-to-LLVM IR transformation pass
- **Line Count**: 598 lines
- **Parent Class**: `BaseAstGenPass[Any]`
- **Key Responsibilities**:
  - Traverse Jac AST (unitree)
  - Generate LLVM IR for plain `def` functions
  - Handle basic arithmetic, assignments, returns, comparisons
  - Type coercion (int ↔ float)
  - Symbol table management with scoped allocas

**Supported Constructs**:
- ✅ Plain `def` functions (non-async, non-method)
- ✅ Integer and float literals
- ✅ Boolean values
- ✅ Binary operations (+, -, *, /, ==, !=, <, >, <=, >=)
- ✅ Unary operations (+, -, not)
- ✅ Variable assignments
- ✅ Return statements
- ✅ Type annotations (int, float, bool, void)

**Unsupported/Missing**:
- ❌ Control flow (if/else, while, for)
- ❌ Methods and async functions
- ❌ Strings and complex data structures
- ❌ Function calls
- ❌ Arrays/lists
- ❌ Objects and classes
- ❌ Variadic parameters

#### 1.2 CLI Integration ([cli.py](jac/jaclang/cli/cli.py#L176-L318))
- **Command**: `jac native`
- **Functionality**:
  - Compiles Jac → LLVM IR
  - JIT executes via llvmlite's MCJIT
  - Supports command-line arguments
  - Optional IR dumping with `--dump_ir`

#### 1.3 CodeGenTarget ([codeinfo.py](jac/jaclang/compiler/codeinfo.py#L43-L47))
```python
class CodeGenTarget:
    llvm_module: Any | None = None           # Type: _ir.Module
    llvm_ir: str = ""                        # LLVM IR text
    llvm_metadata: dict[str, Any] = {}       # Function signatures
    llvm_triple: str = ""                    # Target triple
    llvm_data_layout: str = ""               # Data layout string
```

#### 1.4 JacProgram ([program.py](jac/jaclang/compiler/program.py#L163-L174))
```python
def compile_to_llvm(self, file_path: str, ...) -> uni.Module:
    """Compile Jac file and emit LLVM IR via LlvmIrGenPass."""
    mod_targ = self.compile(file_path, ..., no_cgen=True)
    self.run_schedule(mod=mod_targ, passes=llvm_code_gen)
    return mod_targ
```

### 2. Data Flow Architecture

```
┌─────────────┐
│  .jac File  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ JacParser                               │
│ Parse → Jac AST (unitree)              │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ ir_gen_sched passes:                    │
│ - SymTabBuildPass                       │
│ - DeclImplMatchPass                     │
│ - SemanticAnalysisPass                  │
│ - SemDefMatchPass                       │
│ - CFGBuildPass                          │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ LlvmIrGenPass                           │
│ Walk AST → Generate LLVM IR             │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ CodeGenTarget                           │
│ .llvm_ir                                │
│ .llvm_metadata                          │
│ .llvm_triple                            │
│ .llvm_data_layout                       │
└──────┬──────────────────────────────────┘
       │
       ├─────────────┬──────────────┐
       │             │              │
       ▼             ▼              ▼
┌─────────┐   ┌───────────┐  ┌──────────┐
│jac tool │   │jac native │  │Assembly  │
│  ir     │   │  (MCJIT)  │  │Generation│
└─────────┘   └───────────┘  └──────────┘
               (Proposed)     (Proposed)
```

### 3. Stack-Based Code Generation

The pass uses multiple stacks for nested scope management:

```python
module_stack: list[_ir.Module]          # LLVM modules
builder_stack: list[_ir.IRBuilder]      # IR builders
symbol_stack: list[dict[str, Any]]      # Variable allocas
function_stack: list[_ir.Function]      # Current functions
metadata_stack: list[dict[str, Any]]    # Function metadata
```

**Alloca Strategy**: All variables use entry block allocas (SSA via mem2reg)

## Architectural Issues & Improvements Needed

### Issue 1: Type Safety Violations

**Problem**: Per [notes.md](notes.md), the codebase should be "production-grade type-safe", but:
- `BaseAstGenPass[Any]` uses generic `Any` type
- `symbol_stack: list[dict[str, Any]]` is untyped
- `llvm_module: Any | None` should be properly typed
- Missing protocol definitions for LLVM IR types

**Solution**: Create proper type aliases and protocols
```python
from typing import Protocol, TypeAlias
from llvmlite import ir as _ir

LlvmModule: TypeAlias = _ir.Module
LlvmFunction: TypeAlias = _ir.Function
LlvmValue: TypeAlias = _ir.Value
LlvmType: TypeAlias = _ir.Type

class SymbolTable(TypedDict):
    name: str
    alloca: _ir.AllocaInstr
    type: _ir.Type
```

### Issue 2: Monolithic Pass (598 lines)

**Problem**: Single file handles:
- Module/function traversal
- Expression compilation
- Type resolution
- Symbol management
- Error handling

**Solution**: Separate into focused modules:
```
llvmir/
├── __init__.py
├── llvmir_gen_pass.py       # Main pass orchestrator
├── type_mapper.py           # Jac type → LLVM type mapping
├── expr_compiler.py         # Expression compilation
├── stmt_compiler.py         # Statement compilation
├── symbol_manager.py        # Scoped symbol table
└── ir_builder_ext.py        # LLVM IR builder extensions
```

### Issue 3: Limited Test Coverage

**Current Tests**:
- ✅ 1 integration test in [test_cli.py](jac/jaclang/tests/test_cli.py#L40-L57)

**Missing Tests**:
- ❌ Unit tests for LlvmIrGenPass components
- ❌ Type coercion edge cases
- ❌ Error handling (unsupported constructs)
- ❌ IR correctness verification
- ❌ Various numeric types (i8, i16, i32, f32)

**Solution**: Create comprehensive test suite
```
tests/
├── test_llvm_ir_pass.py     # Pass functionality
├── test_llvm_type_mapper.py # Type mapping
├── test_llvm_expr.py        # Expression codegen
├── test_llvm_errors.py      # Error cases
└── fixtures/
    ├── simple_math.jac
    ├── type_coercion.jac
    └── error_cases.jac
```

### Issue 4: Missing IR/Assembly Output in `jac tool ir`

**Problem**: Users cannot inspect LLVM IR via standard tooling
- `jac tool ir llvmir file.jac` → Not implemented
- No assembly output support

**Solution**: Extend [AstTool.ir()](jac/jaclang/utils/lang_tools.py#L181-L293)
```python
case "llvmir":
    ir = prog.compile_to_llvm(file_name)
    return ir.gen.llvm_ir or "LLVM IR generation failed."

case "llvmir-opt":
    # Optimized LLVM IR
    ir = prog.compile_to_llvm(file_name)
    return optimize_llvm_ir(ir.gen.llvm_ir)

case "asm":
    # Assembly output
    ir = prog.compile_to_llvm(file_name)
    return generate_assembly(ir.gen.llvm_module)
```

### Issue 5: No Assembly Generation

**Problem**: Missing native assembly output for different architectures

**Solution**: Add assembly generation utilities
```python
def generate_assembly(
    llvm_module: _ir.Module,
    target_triple: str | None = None,
    optimization_level: int = 2,
    format: Literal["asm", "obj"] = "asm"
) -> bytes:
    """Generate assembly or object code from LLVM module."""
    target_machine = create_target_machine(target_triple, optimization_level)
    return target_machine.emit_assembly(llvm_module)
```

## Proposed Architecture Improvements

### Phase 1: Type Safety & Refactoring

**Goal**: Production-grade type safety per notes.md

1. **Create type definitions** (`jac/jaclang/compiler/passes/main/llvmir/types.py`)
```python
from typing import TypeAlias, Protocol, TypedDict
from llvmlite import ir as _ir

# LLVM type aliases
LlvmModule: TypeAlias = _ir.Module
LlvmFunction: TypeAlias = _ir.Function
LlvmValue: TypeAlias = _ir.Value
LlvmType: TypeAlias = _ir.Type
LlvmBuilder: TypeAlias = _ir.IRBuilder

# Symbol table entry
class SymbolEntry(TypedDict):
    alloca: _ir.AllocaInstr
    ir_type: _ir.Type
    jac_type: str

# Type mapper protocol
class TypeMapper(Protocol):
    def map_type(self, jac_type: str) -> _ir.Type: ...
    def default_value(self, ir_type: _ir.Type) -> _ir.Constant | None: ...
```

2. **Refactor into modules**:
   - `type_mapper.py`: Type resolution logic
   - `expr_compiler.py`: Expression compilation
   - `stmt_compiler.py`: Statement compilation
   - `symbol_manager.py`: Scoped symbol management

3. **Update CodeGenTarget** with proper types:
```python
from llvmlite import ir as _ir

class CodeGenTarget:
    llvm_module: _ir.Module | None = None      # Properly typed
    llvm_ir: str = ""
    llvm_metadata: dict[str, FunctionSignature] = {}  # Typed metadata
    llvm_triple: str = ""
    llvm_data_layout: str = ""
```

### Phase 2: Comprehensive Testing

**Goal**: 90%+ code coverage for LLVM components

1. **Unit tests for each module**
2. **Integration tests** for end-to-end compilation
3. **Error case tests** for unsupported features
4. **Fixtures** covering:
   - Arithmetic operations
   - Type conversions
   - Edge cases (overflow, underflow)
   - Various return types

### Phase 3: IR/Assembly Output Tools

**Goal**: Complete tooling for LLVM IR inspection

1. **Extend `jac tool ir`** command:
   - `llvmir` - Raw LLVM IR
   - `llvmir-opt` - Optimized LLVM IR
   - `asm` - Assembly code
   - `asm-x86` - x86-64 assembly
   - `asm-arm` - ARM assembly

2. **Add assembly generation utilities**:
```python
# jac/jaclang/compiler/passes/main/llvmir/asm_gen.py
class AssemblyGenerator:
    def generate(
        self,
        module: _ir.Module,
        target: str = "x86_64",
        optimization: int = 2
    ) -> str: ...
```

3. **Update CLI commands**:
   - `jac native --dump-ir` - Already implemented ✅
   - `jac native --dump-asm` - New flag for assembly
   - `jac native --optimize` - Optimization level

### Phase 4: Extended Language Support

**Goal**: Support more Jac constructs

1. **Control flow**: if/else, while, for
2. **Function calls**: Both Jac and external
3. **Arrays**: Basic array support
4. **Strings**: String literals and operations

## Implementation Roadmap

### Sprint 1: Foundation (Type Safety)
- [ ] Create type definitions module
- [ ] Refactor LlvmIrGenPass into separate modules
- [ ] Add type annotations throughout
- [ ] Update CodeGenTarget with proper types

### Sprint 2: Testing Infrastructure
- [ ] Create test suite structure
- [ ] Add unit tests for type mapper
- [ ] Add unit tests for expression compiler
- [ ] Add integration tests
- [ ] Create comprehensive fixtures

### Sprint 3: IR/Assembly Tooling
- [ ] Extend `AstTool.ir()` for LLVM IR output
- [ ] Add assembly generation utilities
- [ ] Update `jac tool ir` command
- [ ] Add assembly output to `jac native`

### Sprint 4: Language Extension
- [ ] Add control flow support
- [ ] Add function call support
- [ ] Add array support
- [ ] Documentation and examples

## File Structure Proposal

```
jac/jaclang/
├── compiler/
│   ├── passes/
│   │   └── main/
│   │       ├── llvmir/
│   │       │   ├── __init__.py
│   │       │   ├── types.py              # Type definitions
│   │       │   ├── type_mapper.py        # Jac → LLVM type mapping
│   │       │   ├── expr_compiler.py      # Expression compilation
│   │       │   ├── stmt_compiler.py      # Statement compilation
│   │       │   ├── symbol_manager.py     # Symbol table management
│   │       │   ├── ir_builder_ext.py     # Builder extensions
│   │       │   └── asm_gen.py            # Assembly generation
│   │       └── llvmir_gen_pass.py        # Main orchestrator
│   └── codeinfo.py                       # Updated with proper types
│
└── tests/
    ├── fixtures/
    │   ├── llvm/
    │   │   ├── simple_math.jac
    │   │   ├── type_coercion.jac
    │   │   ├── control_flow.jac
    │   │   └── error_cases.jac
    │
    └── test_llvm/
        ├── __init__.py
        ├── test_llvm_ir_pass.py
        ├── test_type_mapper.py
        ├── test_expr_compiler.py
        ├── test_stmt_compiler.py
        ├── test_asm_gen.py
        └── test_integration.py
```

## API Examples

### Using `jac tool ir`
```bash
# View LLVM IR
jac tool ir llvmir examples/math.jac

# View optimized IR
jac tool ir llvmir-opt examples/math.jac

# View x86-64 assembly
jac tool ir asm examples/math.jac

# View ARM assembly
jac tool ir asm-arm examples/math.jac
```

### Using `jac native`
```bash
# Execute with IR dump
jac native examples/math.jac --entry add --dump-ir -- 3 4

# Execute with assembly dump
jac native examples/math.jac --entry add --dump-asm -- 3 4

# Execute with optimization
jac native examples/math.jac --entry add --optimize 3 -- 3 4
```

### Programmatic API
```python
from jaclang.compiler.program import JacProgram
from jaclang.compiler.passes.main.llvmir.asm_gen import AssemblyGenerator

# Compile to LLVM IR
prog = JacProgram()
module = prog.compile_to_llvm("example.jac")

# Get IR
llvm_ir = module.gen.llvm_ir

# Generate assembly
asm_gen = AssemblyGenerator()
x86_asm = asm_gen.generate(module.gen.llvm_module, target="x86_64")
arm_asm = asm_gen.generate(module.gen.llvm_module, target="arm")
```

## Conclusion

The current LLVM IR integration provides a solid foundation but requires architectural improvements to meet production standards:

1. **Type Safety**: Critical for maintaining codebase quality per notes.md
2. **Modularity**: Separate concerns for maintainability
3. **Testing**: Comprehensive coverage for reliability
4. **Tooling**: Complete IR/assembly inspection capabilities

This architecture provides a clear path forward for a production-grade LLVM backend for Jac.
