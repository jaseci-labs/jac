"""Tests for type checker narrowing gaps.

Each test documents a specific narrowing limitation. Tests are grouped by gap type:
- Gap A: Early return narrowing lost at join points after nested blocks
- Gap B: Ternary (IfElseExpr) narrowing not applied to function arguments
- Gap C: Ternary narrowing not applied to attribute access

All functions prefixed with ok_ should produce NO errors.
All functions prefixed with fail_ currently produce errors (documenting the gap).
"""

# ============================================================================
# Shared types
# ============================================================================

obj Animal {
    has name: str = "animal";
}

obj Dog(Animal) {
    has bark_count: int = 0;
}

obj Cat(Animal) {
    has meow_count: int = 0;
}

def use_animal(a: Animal) -> str {
    return a.name;
}

def use_dog(d: Dog) -> int {
    return d.bark_count;
}

obj Anchor {
    has id: int = 0;
}

obj Root {
    has anchor: Anchor = Anchor();
}

def use_anchor(a: Anchor) -> int {
    return a.id;
}

def use_root(r: Root) -> Anchor {
    return r.anchor;
}

# ============================================================================
# Gap A: Early return narrowing lost after nested if blocks
#
# After `if val is None { return; }`, val should be narrowed to non-None
# for the ENTIRE rest of the function. Currently the narrowing is lost
# after exiting a nested if block (at the CFG join point).
#
# Root cause: When the CFG backward walk reaches the join point after a
# nested if block, it sees an unnarrowed predecessor from the if's false
# branch, causing `has_unnarrowed_pred = True` which widens back to the
# declared type.
# ============================================================================

# This works: early return narrows, used before any nested block
def ok_early_return_simple(val: Dog | None) -> int {
    if val is None {
        return 0;
    }
    return use_dog(val);
}

# This works: early return narrows, used inside first nested block
def ok_early_return_inside_nested(val: Dog | None, flag: bool) -> int {
    if val is None {
        return 0;
    }
    if flag {
        return use_dog(val);
    }
    return 0;
}

# GAP A1: Narrowing lost after exiting a nested if block
def fail_early_return_after_nested_if(val: Dog | None, flag: bool) -> int {
    if val is None {
        return 0;
    }
    if flag {
        use_dog(val);
    }
    return use_dog(val);  # Error: val is Dog | None (should be Dog)
}

# GAP A2: Narrowing lost after multiple nested if blocks
def fail_early_return_after_two_ifs(val: Dog | None, a: bool, b: bool) -> int {
    if val is None {
        return 0;
    }
    if a {
        use_dog(val);  # Works inside first if
    }
    if b {
        use_dog(val);  # Error: narrowing lost
    }
    return use_dog(val);  # Error: narrowing lost
}

# GAP A3: Truthiness guard with early return, same issue
def fail_truthiness_early_return_nested(val: Dog | None, flag: bool) -> int {
    if not val {
        return 0;
    }
    if flag {
        use_dog(val);
    }
    return use_dog(val);  # Error: val is Dog | None (should be Dog)
}

# GAP A4: isinstance guard with early return
def fail_isinstance_early_return_nested(val: Animal, flag: bool) -> int {
    if not isinstance(val, Dog) {
        return 0;
    }
    if flag {
        use_dog(val);
    }
    return use_dog(val);  # Error: val is Animal (should be Dog)
}

# ============================================================================
# Gap B: Ternary narrowing not applied to function call arguments
#
# In `use_foo(val) if isinstance(val, Foo) else default`, the scope-based
# narrowing correctly narrows `val` in the true branch. However, when `val`
# is used as a function argument, the type is resolved through the
# get_type_of_symbol -> get_narrowed_type CFG path, which doesn't see
# the scope-based narrowing.
#
# Root cause: Ternary narrowing uses push_narrowing_scope/pop_narrowing_scope
# which only affects get_type_of_expression for direct Name lookups. When
# the Name is a function argument, FuncCall type checking uses
# get_type_of_expression on the arg, which should check scope narrowing
# but the narrowing context may not be consulted for argument type checking.
# ============================================================================

# This works: direct use of narrowed variable in ternary
def ok_ternary_isinstance_direct(val: Dog | None) -> Dog {
    return val if isinstance(val, Dog) else Dog();
}

# This works: narrowed variable in list literal in ternary
def ok_ternary_isinstance_list(val: Dog | None) -> list[Dog] {
    return [val] if isinstance(val, Dog) else [];
}

# GAP B1: Narrowed variable passed to function in ternary (isinstance)
def fail_ternary_isinstance_fn_arg(val: Dog | None) -> int {
    return use_dog(val) if isinstance(val, Dog) else 0;  # Error
}

# GAP B2: Narrowed variable passed to function in ternary (is not None)
def fail_ternary_is_not_none_fn_arg(val: Dog | None) -> int {
    return use_dog(val) if val is not None else 0;  # Error
}

# GAP B3: Narrowed variable passed to function in ternary (truthiness)
def fail_ternary_truthiness_fn_arg(val: Dog | None) -> int {
    return use_dog(val) if val else 0;  # Error
}

# ============================================================================
# Gap C: Ternary narrowing not applied to attribute access
#
# In `val.attr if val else default`, the true branch should narrow `val`
# from T|None to T, allowing `.attr` access. Currently the narrowing
# doesn't apply and the checker reports that NoneType has no attribute.
#
# Root cause: Same as Gap B — the scope-based narrowing doesn't reach
# the attribute resolution path for AtomTrailer nodes.
# ============================================================================

# GAP C1: Attribute access on truthiness-narrowed variable in ternary
def fail_ternary_attr_truthiness(val: Dog | None) -> int {
    return val.bark_count if val else 0;  # Error: Dog|None has no bark_count
}

# GAP C2: Attribute access on isinstance-narrowed variable in ternary
def fail_ternary_attr_isinstance(val: Animal) -> int {
    return val.bark_count if isinstance(val, Dog) else 0;  # Error
}

# GAP C3: Method-like attribute access on narrowed variable in ternary
def fail_ternary_attr_chain(`root: Root | None) -> int {
    return use_anchor(`root.anchor) if `root else 0;  # Error
}

# ============================================================================
# Gap D: Assignment in if-body should narrow type after the if block
#
# When `x: T | None = None; if not x { x = T(); }`, x should be T after
# the if block because both branches guarantee non-None:
# - False branch: x was truthy → already T
# - True branch: x was reassigned to T()
#
# Root cause: exclude_type_from_union returns the original when excluding a
# non-union type from itself (NoneType - NoneType → NoneType instead of Never).
# This makes the false branch return NoneType instead of NeverType, poisoning
# the join-point merge with an incorrect type.
#
# Mirrors: runtime.impl.jac ContextVar.get(None) / reassign pattern
# ============================================================================

# --- ok_ functions: patterns that should work (lines 210-260) ---

def ok_assign_in_if_narrows_obj(x: Animal | None) -> str {
    # After if-body reassignment, x is guaranteed Animal
    if not x {
        x = Dog();
    }
    return x.name;
}

def ok_assign_in_if_narrows_str(x: str | None) -> str {
    if not x {
        x = "default";
    }
    return x.upper();
}

def ok_assign_in_if_none_check(x: Animal | None) -> str {
    if x is None {
        x = Dog();
    }
    return x.name;
}

def ok_assign_in_if_with_intervening(x: Dog | None) -> int {
    flag = False;
    if not x {
        x = Dog();
        flag = True;
    }
    y = 10;
    return x.bark_count + y;
}

import from contextvars { ContextVar }

def ok_contextvar_get_reassign(cv: ContextVar[Animal]) -> str {
    # ContextVar.get(None) returns T | None; reassign in if-body should narrow
    x = cv.get(None);
    if not x {
        x = Dog();
    }
    return x.name;
}

def ok_contextvar_get_with_set(cv: ContextVar[Dog]) -> int {
    x = cv.get(None);
    if not x {
        cv.set(Dog());
        x = cv.get();
    }
    return x.bark_count;
}

import from queue { Queue }

obj CallStateTest {
    has reports: Queue = Queue(),
        _sentinel: object = object();
}

def ok_try_finally_narrowing(cv: ContextVar[CallStateTest]) -> list {
    # Exact runtime.impl.jac pattern: narrowing must propagate through try/finally
    cs = cv.get(None);
    owns = False;
    if not cs {
        cv.set(CallStateTest());
        cs = cv.get();
        owns = True;
    }
    try {
        result = 42;
        return [result];
    } finally {
        if owns {
            reports: list = [];
            while not cs.reports.empty() {
                item = cs.reports.get_nowait();
                if item is not cs._sentinel {
                    reports.append(item);
                }
            }
        }
    }
}
