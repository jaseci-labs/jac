# TypeScript Parser Implementation Plan

## Overview

Create a TypeScript/JavaScript parser that generates an AST using the existing unitree.py nodes, focusing on correct symbol table information extraction for UniScopeNode. Since TypeScript is not strictly LALR(1), we'll make concessions to ensure all valid TS programs can be parsed while preserving symbol information accuracy.

## Goals

1. Parse any valid TypeScript/JavaScript file
2. Generate AST using existing unitree.py nodes where possible
3. Correctly populate UniScopeNode symbol tables for:
   - Variable declarations (let, const, var)
   - Function declarations and expressions
   - Class declarations with methods and properties
   - Interface declarations
   - Type aliases
   - Enum declarations
   - Namespace/Module declarations
   - Import/Export statements
4. Support type annotations for symbol table enrichment

## Files to Create/Modify

### New Files

1. **`/home/marsninja/repos/jaseci/jac/jaclang/compiler/ts.lark`**
   - TypeScript/JavaScript grammar in Lark format
   - Focus on constructs that define symbols

2. **`/home/marsninja/repos/jaseci/jac/jaclang/compiler/ts_parser.py`**
   - TypeScriptParser class extending Transform
   - TreeToAST transformer for TS grammar rules

3. **`/home/marsninja/repos/jaseci/jac/jaclang/compiler/ts_constant.py`**
   - TypeScript-specific token definitions

### Modified Files

1. **`/home/marsninja/repos/jaseci/jac/jaclang/compiler/__init__.py`**
   - Add TypeScript parser generation function
   - Export TypeScript parser and TOKEN_MAP

## Implementation Phases

### Phase 1: Grammar Design (ts.lark)

Design a simplified TypeScript grammar focusing on:

#### 1.1 Declarations (Symbol-Creating Constructs)

```lark
// Variable declarations
var_decl: ("var" | "let" | "const") binding_list ";"?
binding_list: binding ("," binding)*
binding: binding_pattern type_annotation? initializer?
binding_pattern: NAME | array_binding | object_binding

// Function declarations
func_decl: "async"? "function" "*"? NAME? type_params? "(" param_list? ")" type_annotation? block
arrow_func: "async"? type_params? "(" param_list? ")" type_annotation? "=>" (expression | block)
           | "async"? NAME "=>" (expression | block)

// Class declarations
class_decl: decorators? "abstract"? "class" NAME type_params? extends_clause? implements_clause? class_body
class_body: "{" class_member* "}"
class_member: access_modifier? "static"? "readonly"? (property_decl | method_decl | constructor_decl | accessor_decl)

// Interface declarations
interface_decl: "interface" NAME type_params? extends_list? "{" interface_member* "}"

// Type alias
type_alias: "type" NAME type_params? "=" type ";"?

// Enum declarations
enum_decl: "const"? "enum" NAME "{" enum_member_list? "}"

// Namespace/Module
namespace_decl: ("namespace" | "module") NAME "{" statement* "}"
```

#### 1.2 Import/Export (Module System)

```lark
import_stmt: "import" import_clause from_clause ";"?
           | "import" module_specifier ";"?
           | "import" "type" import_clause from_clause ";"?

export_stmt: "export" declaration
           | "export" "{" export_list "}" from_clause?
           | "export" "*" from_clause
           | "export" "default" expression ";"?
           | "export" "=" expression ";"?
```

#### 1.3 Expressions (Simplified for Symbol Resolution)

```lark
expression: assignment_expr
assignment_expr: conditional_expr (assignment_op assignment_expr)?
conditional_expr: logical_or ("?" expression ":" expression)?
// ... binary/unary operators with proper precedence
member_expr: primary_expr (("." | "?.") NAME | "[" expression "]" | "(" arg_list? ")")*
primary_expr: "this" | "super" | NAME | literal | array_literal | object_literal | "(" expression ")" | template_literal
```

#### 1.4 Type System (For Type Annotations)

```lark
type: primary_type
    | union_type
    | intersection_type
    | function_type
    | constructor_type
    | typeof_type
    | keyof_type

primary_type: NAME type_args?
            | "void" | "null" | "undefined" | "never" | "any" | "unknown"
            | array_type
            | tuple_type
            | object_type
            | literal_type
```

### Phase 2: Parser Implementation (ts_parser.py)

#### 2.1 Core Parser Structure

```python
class TypeScriptParser(Transform[uni.Source, uni.Module]):
    """TypeScript Parser."""

    def __init__(self, root_ir: uni.Source, prog: JacProgram, cancel_token: Event | None = None):
        self.mod_path = root_ir.loc.mod_path
        self.node_list: list[uni.UniNode] = []
        self._node_ids: set[int] = set()
        Transform.__init__(self, ir_in=root_ir, prog=prog, cancel_token=cancel_token)

    def transform(self, ir_in: uni.Source) -> uni.Module:
        # Parse and transform to AST
        pass

    class TreeToAST(TSTransformer):
        # Rule-specific handlers
        pass
```

#### 2.2 Node Mapping Strategy

Map TypeScript constructs to existing unitree nodes where possible:

| TypeScript Construct | Unitree Node |
|---------------------|--------------|
| function declaration | uni.Ability |
| class declaration | uni.Archetype |
| interface declaration | uni.Archetype (with interface flag) |
| variable declaration | uni.Assignment or uni.HasVar |
| import statement | uni.Import |
| type alias | New: uni.TypeAlias |
| enum declaration | uni.Enum |
| namespace | uni.Module (nested) |
| method | uni.Ability |
| property | uni.HasVar |

#### 2.3 Symbol Table Population

Key areas for symbol table correctness:

1. **Scope Creation**: Create UniScopeNode for:
   - Module (file level)
   - Functions (including arrow functions)
   - Classes
   - Interfaces
   - Namespaces
   - Block statements (let/const scoping)

2. **Symbol Registration**:
   - Insert declarations into appropriate scope
   - Handle hoisting for `var` and function declarations
   - Track type information in symbol metadata

3. **Reference Resolution**:
   - Link variable uses to declarations
   - Handle scope chain lookup
   - Support TypeScript's module resolution

### Phase 3: LALR Concessions

TypeScript has several non-LALR constructs. Handle them as follows:

#### 3.1 Arrow Function vs Parenthesized Expression

The ambiguity `(a) =>` vs `(a)`:
- Solution: Parse `(params)` greedily, then check for `=>` to determine if it's an arrow function
- Use Lark's ambiguity handling or reparse

#### 3.2 Generic Type vs Comparison

The ambiguity `foo<T>()` vs `foo < T > ()`:
- Solution: In expression context, prefer generic interpretation when followed by `(`
- May require lexer states or lookahead

#### 3.3 Type Assertions

`<Type>expr` vs JSX:
- Solution: Treat `<` in expression position as type assertion in .ts files
- Treat as JSX in .tsx files (can be controlled by file extension)

#### 3.4 Automatic Semicolon Insertion (ASI)

- Make semicolons optional in grammar
- Use error recovery to handle missing semicolons
- Similar to existing Jac parser's `_MISSING_TOKENS` approach

### Phase 4: Testing Strategy

1. **Unit Tests**: Test individual grammar rules
2. **Integration Tests**: Parse real TypeScript files
3. **Symbol Table Tests**: Verify correct scope hierarchy and symbol resolution
4. **Comparison Tests**: Compare parsed AST with TypeScript compiler's output

## Detailed File Specifications

### ts.lark Structure

```lark
// Entry point
start: source_file

source_file: statement*

// Statements
statement: var_stmt
         | func_decl
         | class_decl
         | interface_decl
         | type_alias_decl
         | enum_decl
         | namespace_decl
         | import_stmt
         | export_stmt
         | if_stmt
         | while_stmt
         | for_stmt
         | for_in_stmt
         | for_of_stmt
         | try_stmt
         | switch_stmt
         | with_stmt
         | return_stmt
         | throw_stmt
         | break_stmt
         | continue_stmt
         | debugger_stmt
         | labeled_stmt
         | block_stmt
         | expr_stmt
         | empty_stmt

// ... detailed grammar rules (see full grammar in implementation)

// Tokens
NAME: /[a-zA-Z_$][a-zA-Z0-9_$]*/
STRING: /"([^"\\]|\\.)*"/ | /'([^'\\]|\\.)*'/
NUMBER: /0[xX][0-9a-fA-F]+/ | /0[oO][0-7]+/ | /0[bB][01]+/ | /\d+(\.\d*)?([eE][+-]?\d+)?/
TEMPLATE_HEAD: /`([^`$\\]|\\.)*(${)?/
// ... more tokens
```

### ts_parser.py Key Methods

```python
class TreeToAST(TSTransformer):
    def func_decl(self, _: None) -> uni.Ability:
        """Transform function declaration."""
        is_async = self.match_token(TsTok.KW_ASYNC) is not None
        self.consume_token(TsTok.KW_FUNCTION)
        is_generator = self.match_token(TsTok.STAR_MUL) is not None
        name = self.match(uni.Name)
        type_params = self.match(uni.TypeParams)
        params = self.consume(list)
        return_type = self.match(uni.TypeAnnotation)
        body = self.consume(list)

        return uni.Ability(
            name=name,
            is_async=is_async,
            is_generator=is_generator,
            signature=uni.FuncSignature(...),
            body=body,
            kid=self.flat_cur_nodes,
        )

    def class_decl(self, _: None) -> uni.Archetype:
        """Transform class declaration."""
        # ... implementation

    def var_stmt(self, _: None) -> uni.Assignment | uni.GlobalVars:
        """Transform variable declaration."""
        # ... implementation
```

## Dependencies

- Lark parser library (already in vendor)
- Existing unitree.py node types
- Transform base class from passes

## Estimated Scope

- ts.lark: ~500-700 lines
- ts_parser.py: ~2000-3000 lines (similar to parser.py)
- ts_constant.py: ~200 lines
- Tests: ~500 lines

## Design Decisions (Confirmed)

1. **JSX Support**: Yes - full JSX/TSX syntax support for React compatibility
2. **Decorators**: Stage 2 (Experimental) - `@decorator` syntax used by Angular, NestJS
3. **Type-only imports**: Mark with metadata - distinguish from regular imports in symbol table
4. **File support**: Both .ts/.tsx and .js/.jsx files with the same parser
5. **Feature scope**: Common patterns - classes, functions, interfaces, basic types, imports/exports

## Next Steps After Approval

1. Create ts_constant.py with TypeScript tokens
2. Create ts.lark grammar file
3. Create ts_parser.py with TypeScriptParser class
4. Update compiler/__init__.py for parser generation
5. Write tests for symbol table correctness
6. Iterate on grammar for edge cases
