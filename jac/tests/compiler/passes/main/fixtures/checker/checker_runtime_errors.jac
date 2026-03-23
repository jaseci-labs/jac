"""Tests for type checker limitations found in runtime.impl.jac.

Each test documents a specific checker limitation with minimal reproduction cases.
All functions prefixed with fail_ currently produce false positive errors.
All functions prefixed with ok_ should produce no errors and must not regress.

Tests use ATTRIBUTE ACCESS patterns (AtomTrailer nodes) to match the real code,
not just simple Name nodes. This is critical because the scope narrowing check
before the type cache must handle both Name and AtomTrailer nodes.

Issue 1: Truthiness + isinstance narrowing on attribute access in `and` chains
Issue 2: Compound `or` guard narrowing on attribute access after early exit
"""

import from types { UnionType }

# ============================================================================
# Shared types — mirror runtime.impl.jac structures
# ============================================================================

obj Spec {
    has origin: str | None = "/path",
        loader: str = "default";
}

obj SpatialFunc {
    has trigger: (type | UnionType | tuple | None) = None,
        func: str = "noop";
}

obj Walker {
    has funcs: list[SpatialFunc] = [];
}

def use_type(t: type) -> str {
    return str(t);
}

def use_types(t: (type | UnionType | tuple)) -> str {
    return str(t);
}

def use_spec(s: Spec) -> str {
    return s.loader;
}

def all_issubclass(classes: (type | UnionType | tuple), target: type) -> bool {
    return True;
}

# ============================================================================
# Issue 1: Truthiness narrowing on ATTRIBUTE ACCESS in `and` chains
#
# In `obj.attr and f(obj.attr)` where attr is `T | None`, truthiness should
# narrow obj.attr to T in subsequent operands. This requires the scope narrowing
# check before the type cache to handle AtomTrailer nodes, not just Names.
#
# Mirrors: runtime.impl.jac `i.trigger and all_issubclass(i.trigger, ...)`
# ============================================================================

# --- ok_ functions: patterns that should work ---

def ok_attr_truthiness_simple(sf: SpatialFunc) -> str {
    # Truthiness on attr in if condition — scope narrowing on AtomTrailer
    if sf.trigger {
        return use_types(sf.trigger);
    }
    return "";
}

def ok_attr_truthiness_and_chain(sf: SpatialFunc) -> str {
    # Truthiness + function call in `and` chain on attribute
    if sf.trigger and use_types(sf.trigger) {
        return "matched";
    }
    return "";
}

def ok_attr_isinstance_and_chain(sf: SpatialFunc) -> str {
    # Truthiness + isinstance in `and` chain on attribute
    # After truthiness narrows to type|UnionType|tuple, isinstance narrows to type
    if sf.trigger and isinstance(sf.trigger, type) {
        return use_type(sf.trigger);
    }
    return "";
}

def ok_attr_truthiness_loop(w: Walker) -> str {
    # Loop variable attribute access — mirrors `for i in warch._jac_entry_funcs_`
    for sf in w.funcs {
        if sf.trigger and use_types(sf.trigger) {
            return "found";
        }
    }
    return "";
}

def ok_attr_isinstance_loop(w: Walker) -> str {
    # Full runtime.impl.jac pattern: loop + truthiness + isinstance + fn call
    for sf in w.funcs {
        if (
            sf.trigger
            and all_issubclass(sf.trigger, object)
        ) {
            return "matched";
        }
    }
    return "";
}

# ============================================================================
# Issue 2: Compound `or` guard narrowing on ATTRIBUTE ACCESS after early exit
#
# After `if (not obj or not obj.attr) { raise; }`, obj is narrowed to non-None.
# Subsequent attribute access like `obj.attr` should work without error.
# This requires both the OR predicate fix (_find_predicate_for) AND the
# AtomTrailer scope narrowing check before the type cache.
#
# Mirrors: runtime.impl.jac `if (not spec or not spec.origin) { raise; }`
# ============================================================================

# --- ok_ functions: patterns that should work ---

def ok_simple_none_guard_attr(spec: Spec | None) -> str {
    # Simple guard + attr access — baseline
    if spec is None {
        raise ValueError("no spec");
    }
    return spec.loader;
}

def ok_compound_or_guard_attr(spec: Spec | None) -> str {
    # Compound `or` guard — narrows spec to non-None for attr access
    if not spec or not spec.origin {
        raise ValueError("missing");
    }
    return spec.loader;
}

def ok_compound_or_guard_parens(spec: Spec | None) -> str {
    # Same with parentheses (AtomUnit wrapping BoolExpr)
    if (not spec or not spec.origin) {
        raise ValueError("missing");
    }
    return use_spec(spec);
}

def ok_compound_or_guard_return(spec: Spec | None) -> str {
    # Compound `or` guard with return instead of raise
    if (not spec or not spec.origin) {
        return "";
    }
    return use_spec(spec);
}

def ok_compound_or_guard_chained(spec: Spec | None) -> str {
    # Multiple attr accesses after compound or guard
    if (not spec or not spec.origin) {
        raise ValueError("missing");
    }
    if spec.origin and spec.origin.endswith(".py") {
        return spec.loader;
    }
    return "";
}

def ok_compound_or_guard_attr_direct(spec: Spec | None) -> str | None {
    # Direct attribute access after compound or guard
    # Note: spec is narrowed to Spec, but spec.origin is still str|None
    # (the guard checks truthiness of origin, but doesn't narrow its type)
    if (not spec or not spec.origin) {
        raise ValueError("missing");
    }
    return spec.origin;
}
