# Implementation Plan: CFG-Based Type Narrowing

## Overview

Add flow-sensitive type narrowing to the type checker so that `isinstance()` and `is None`/`is not None` guards narrow variable types inside conditional branches, and types widen back at join points. This makes the TDD test (`test_type_narrowing`) pass with exactly 1 error.

## Approach: Stack-Based Narrowing During AST Traversal

Build the narrowing context during the existing `TypeCheckPass` visitor traversal. When entering `IfStmt`/`ElseIf`/`ElseStmt`, push narrowing onto a stack on the `TypeEvaluator`. When exiting, pop it. The evaluator consults the stack when resolving `Name` nodes.

**Why this approach:**

- No changes to `UniCFGNode` or `CFGBuildPass`
- Leverages the natural enter/exit visitor ordering
- Narrowing automatically expires at join points (after `exit_if_stmt`)
- Uses simple AST checks for early-return detection (is last body statement a `ReturnStmt`?)

**Key dispatch fact:** `type(node).__name__` drives handler dispatch:

- `IfStmt` → `enter_if_stmt` / `exit_if_stmt`
- `ElseIf` → `enter_else_if` / `exit_else_if` (separate from IfStmt despite inheritance)
- `ElseStmt` → `enter_else_stmt` / `exit_else_stmt`

**IfStmt kid traversal order:** `[KW_IF, condition, LBRACE, *body, RBRACE, ?else_body]`
→ body is traversed BEFORE else_body, enabling the context swap in `enter_else_*`.

---

## Step 1: Add narrowing infrastructure to TypeEvaluator

### File: `jac/jaclang/compiler/type_system/type_evaluator.jac`

Add to the `TypeEvaluator` obj declarations:

```jac
def get_narrowed_type(symbol: uni.Symbol) -> TypeBase | None;
def extract_narrowing_predicates(condition: uni.Expr) -> list;
def exclude_type_from_union(original: TypeBase, to_exclude: TypeBase) -> TypeBase;
```

### File: `jac/jaclang/compiler/type_system/type_evaluator.impl/type_evaluator.impl.jac`

**In `TypeEvaluator.init()` (after line 834):**

```jac
self.narrowing_stack: list[dict[str, TypeBase]] = [];
```

**`get_narrowed_type()`** -- Walk the stack top-to-bottom, return first match for the symbol name, or None.

**`extract_narrowing_predicates()`** -- Pattern-match the condition expression:

| Pattern | AST Shape | True Branch | False Branch |
|---------|-----------|-------------|--------------|
| `isinstance(x, T)` | `FuncCall(target=Name("isinstance"), params=[Name, Name])` | narrow to T (instance) | exclude T from union |
| `x is None` | `CompareExpr(left=Name, ops=[KW_IS], rights=[Null])` | narrow to NoneType | exclude NoneType |
| `x is not None` | `CompareExpr(left=Name, ops=[KW_ISN], rights=[Null])` | exclude NoneType | narrow to NoneType |

Returns a list of tuples: `(symbol_name, true_type, false_type)` where true/false types are the narrowed types for each branch.

For isinstance: resolve `params[1]` to get the ClassType, then look up the variable's declared type. The true_type is the isinstance type (converted to instance). The false_type is `exclude_type_from_union(declared_type, isinstance_type)`.

For None checks: use `self.prefetch.none_type_class` as the NoneType. The excluded result is computed via `exclude_type_from_union`.

**`exclude_type_from_union()`** -- Given a `UnionType` and a type to exclude, filter the union's `.types` list. If one type remains, return it unwrapped. Compare using `ClassType.shared` equality for class types.

---

## Step 2: Modify type resolution to consult narrowing

### File: `jac/jaclang/compiler/type_system/type_evaluator.impl/type_evaluator.impl.jac`

**In `get_type_of_expression()` (lines 683-697):**
Skip cached `node_.type` for Name nodes when narrowing is active, and don't cache narrowed results:

```jac
if node_.type is not None {
    if not (self.narrowing_stack and isinstance(node_, (uni.Name, uni.SpecialVarRef))) {
        return node_.type;
    }
}
result = self._get_type_of_expression_core(node_);
if not (self.narrowing_stack and isinstance(node_, (uni.Name, uni.SpecialVarRef))) {
    node_.type = result;
}
return result;
```

**In `_get_type_of_expression_core()`, Name case (~line 313):**
After `symbol_type = self.get_type_of_symbol(symbol);`, before the overload check:

```jac
if narrowed := self.get_narrowed_type(symbol) {
    symbol_type = narrowed;
}
```

---

## Step 3: Push/pop/swap narrowing in TypeCheckPass

### File: `jac/jaclang/compiler/passes/main/type_checker_pass.jac`

Add 6 handler declarations:

```jac
def enter_if_stmt(self: TypeCheckPass, <>node: uni.IfStmt) -> None;
def exit_if_stmt(self: TypeCheckPass, <>node: uni.IfStmt) -> None;
def enter_else_if(self: TypeCheckPass, <>node: uni.ElseIf) -> None;
def exit_else_if(self: TypeCheckPass, <>node: uni.ElseIf) -> None;
def enter_else_stmt(self: TypeCheckPass, <>node: uni.ElseStmt) -> None;
def exit_else_stmt(self: TypeCheckPass, <>node: uni.ElseStmt) -> None;
```

### File: `jac/jaclang/compiler/passes/main/impl/type_checker_pass.impl.jac`

Also in `before_pass`, init: `self.early_return_narrowing_depth: int = 0;`

**`enter_if_stmt`:**

1. Extract narrowing predicates from `<>node.condition`
2. Build `{symbol_name: true_branch_type}` dict
3. Push onto `self.evaluator.narrowing_stack`
4. Store predicates on node as `<>node._narrowing_preds` for else/elif to use

**`exit_if_stmt`:**

1. Pop the TRUE-branch context (if else_body didn't consume it -- check stack depth)
2. **Early-return detection**: if `<>node.else_body is None` and body's last statement is `ReturnStmt` or `RaiseStmt`, push FALSE-branch narrowing for subsequent siblings. Increment `self.early_return_narrowing_depth`.

**`enter_else_if`:**

1. Pop parent IfStmt's TRUE-branch context
2. Get parent's predicates from `parent._narrowing_preds`
3. Compute cumulative FALSE type (excluding all preceding conditions' types)
4. Extract this ElseIf's own condition predicates
5. Push combined narrowing: `{symbol: elif_true_type}`
6. Store own predicates as `<>node._narrowing_preds`

**`exit_else_if`:**

1. Pop this ElseIf's context

**`enter_else_stmt`:**

1. Pop preceding context (TRUE or ElseIf)
2. Find parent IfStmt, get predicates, compute remaining type after excluding all preceding conditions
3. Push FALSE-branch narrowing

**`exit_else_stmt`:**

1. Pop FALSE-branch context

**In `exit_ability`** (existing handler), add cleanup:

```jac
while self.early_return_narrowing_depth > 0 {
    if self.evaluator.narrowing_stack {
        self.evaluator.narrowing_stack.pop();
    }
    self.early_return_narrowing_depth -= 1;
}
```

---

## Traversal Walkthroughs

### Simple if/else: `if isinstance(animal, Dog) { d: Dog = animal; } else { c: Cat = animal; }`

```
enter_if_stmt(IfStmt)         → push {animal: Dog}
  traverse body                → d: Dog = animal → narrowed to Dog ✓
  enter_else_stmt(ElseStmt)   → pop Dog, push {animal: Cat}
    traverse body              → c: Cat = animal → narrowed to Cat ✓
  exit_else_stmt               → pop Cat
exit_if_stmt                   → stack clean
next_stmt                      → no narrowing → Dog|Cat ✓
```

### Early return: `if val is None { return "default"; } result: str = val;`

```
enter_if_stmt(IfStmt)         → push {val: NoneType}
  traverse body                → return "default" (narrowed but irrelevant)
exit_if_stmt                   → pop NoneType
                                 detect: no else_body, body ends in ReturnStmt
                                 → push {val: str} for subsequent siblings
result: str = val              → narrowed to str ✓
exit_ability                   → pop early-return narrowing
```

### Elif chain: `if isinstance(a, Dog) {} elif isinstance(a, Cat) {} else {}`

```
enter_if_stmt(IfStmt, Dog)    → push {a: Dog}
  traverse body                → Dog ✓
  enter_else_if(ElseIf, Cat)  → pop Dog, push {a: Cat}
    traverse body              → Cat ✓
    enter_else_stmt(ElseStmt) → pop Cat, push {a: Fish} (remaining)
      traverse body            → Fish ✓
    exit_else_stmt             → pop Fish
  exit_else_if                 → stack clean
exit_if_stmt                   → stack clean
```

---

## Files Modified

| File | Changes |
|------|---------|
| `jac/jaclang/compiler/type_system/type_evaluator.jac` | Add 3 method declarations |
| `jac/jaclang/compiler/type_system/type_evaluator.impl/type_evaluator.impl.jac` | Add `narrowing_stack` init; implement `get_narrowed_type`, `extract_narrowing_predicates`, `exclude_type_from_union`; modify cache in `get_type_of_expression`; add narrowing lookup in `_get_type_of_expression_core` |
| `jac/jaclang/compiler/passes/main/type_checker_pass.jac` | Add 6 enter/exit handler declarations |
| `jac/jaclang/compiler/passes/main/impl/type_checker_pass.impl.jac` | Implement 6 handlers; add `early_return_narrowing_depth` tracking; add cleanup in `exit_ability` |

No changes to `unitree.py`, `cfg_build_pass`, or any other infrastructure.

---

## Verification

```bash
# Primary: TDD test should pass (1 error -- join-point only)
pytest tests/compiler/passes/main/test_checker_pass.py::test_type_narrowing -xvs

# Regression: all existing tests must still pass
pytest tests/compiler/passes/main/test_checker_pass.py -x

# Full pass suite sanity
pytest tests/compiler/passes/main/ -x
```
