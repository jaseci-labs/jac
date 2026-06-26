"""P2 phase-exit: pointer idiom fixture validates free()-elision,
malloc(sizeof(T))→T() lowering, and T* params typed as T."""

import os;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.c2jac.driver { transpile_c_str }
import from jaclang.compiler.c2jac.tags { Idiom }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "c2jac", "fixtures");

def _transpile(name: str) -> str {
    with open(os.path.join(FIXTURES, name)) as f {
        src = f.read();
    }
    (jac_str, tags) = transpile_c_str(src, name);
    return jac_str;
}

def _transpile_tags(name: str) -> tuple {
    with open(os.path.join(FIXTURES, name)) as f {
        src = f.read();
    }
    return transpile_c_str(src, name);
}

test "pointers.c transpiles without error" {
    jac_str = _transpile("pointers.c");
    assert jac_str != "";
}

test "pointers.c struct pointer params annotated as struct type" {
    jac_str = _transpile("pointers.c");
    assert ": Point" in jac_str , f"Expected ': Point' annotation, got:\n{jac_str}";
}

test "pointers.c free() call is elided" {
    jac_str = _transpile("pointers.c");
    assert "free" not in jac_str , f"Expected free() to be removed, got:\n{jac_str}";
}

test "pointers.c malloc(sizeof(Point)) lowered to Point() constructor" {
    jac_str = _transpile("pointers.c");
    assert "Point()" in jac_str , f"Expected Point() constructor, got:\n{jac_str}";
}

test "pointers.c struct field access p->x becomes p.x" {
    jac_str = _transpile("pointers.c");
    assert ".x" in jac_str , f"Expected .x field access, got:\n{jac_str}";
}

# ---------------------------------------------------------------------------- #
# §7.2/§7.4/§7.5 — list-of-objects, pointer-as-reference, realloc-elide         #
# ---------------------------------------------------------------------------- #
test "ptr_idioms.c transpiles with no Tier-B leakage" {
    (jac_str, tags) = _transpile_tags("ptr_idioms.c");
    assert jac_str != "";
    leaks = tags.tier_b_entries();
    assert len(leaks) == 0 , f"Expected all-Tier-A, got Tier-B sites: {[
        nt.reason for nt in leaks
    ]}";
    assert "__c2jac_unsupported" not in jac_str , f"Unexpected surrogate in output:\n{jac_str}";
}

test "ptr_idioms.c malloc(n*sizeof(T)) lowers to list-of-objects" {
    (jac_str, tags) = _transpile_tags("ptr_idioms.c");
    assert "list[Point]" in jac_str , f"Expected list[Point] annotation, got:\n{jac_str}";
    assert "[Point() for _ in range(n)]" in jac_str , f"Expected list comprehension of Point(), got:\n{jac_str}";
    assert "malloc" not in jac_str , f"Expected malloc elided, got:\n{jac_str}";
    assert len(tags.by_idiom(Idiom.LIST_OF_OBJECTS)) == 1 , "Expected one LIST_OF_OBJECTS idiom recognized";
}

test "ptr_idioms.c realloc on list-bound pointer is elided (Tier-A)" {
    (jac_str, tags) = _transpile_tags("ptr_idioms.c");
    assert "realloc" not in jac_str , f"Expected realloc elided, got:\n{jac_str}";
    re = tags.by_idiom(Idiom.REALLOC_ELIDE);
    assert len(re) == 1 , "Expected one REALLOC_ELIDE idiom";
    assert re[0].tier.value == "tier_a" , "realloc on a list-bound pointer should be Tier-A";
}

test "ptr_idioms.c pointer dereference and address-of become references" {
    (jac_str, tags) = _transpile_tags("ptr_idioms.c");
    # (*p).x and p->y both collapse to attribute access on the reference.
    assert "p.x + p.y" in jac_str , f"Expected p.x + p.y, got:\n{jac_str}";
    # &p->x passed as a reference → just p.x.
    assert "set_field(p.x, v)" in jac_str , f"Expected set_field(p.x, v), got:\n{jac_str}";
    assert len(tags.by_idiom(Idiom.PTR_REF)) == 3 , f"Expected 3 PTR_REF idioms, got {len(
        tags.by_idiom(Idiom.PTR_REF)
    )}";
}

test "ptr_idioms.c non-list-bound realloc stays Tier-B" {
    src = "void *realloc(void *p, unsigned int n);\n" + "int f(int *raw) { raw = realloc(raw, 8); return 0; }\n";
    (jac_str, tags) = transpile_c_str(src, "raw_realloc.c");
    re = tags.by_idiom(Idiom.REALLOC_ELIDE);
    assert len(re) == 1 , "Expected one REALLOC_ELIDE idiom";
    assert re[0].tier.value == "tier_b" , "realloc on a pointer not proven list-bound should be Tier-B";
}

test "list-bound pointer overwritten by raw buffer falls back to Tier-B" {
    # §7.5: list-boundness must be invalidated by a non-list rebind. After
    # `arr = malloc(...)` marks arr list-bound, `arr = raw` overwrites it with an
    # unproven buffer, so the trailing realloc can no longer claim Tier-A.
    src = "void *malloc(unsigned int n);\nvoid *realloc(void *p, unsigned int n);\n" + "void *make(int *raw, int n) {\n" + "  int *arr = malloc(n * sizeof(int));\n" + "  arr = raw;\n" + "  arr = realloc(arr, 2 * n * sizeof(int));\n" + "  return arr;\n}\n";
    (jac_str, tags) = transpile_c_str(src, "overwritten_realloc.c");
    re = tags.by_idiom(Idiom.REALLOC_ELIDE);
    assert len(re) == 1 , "Expected one REALLOC_ELIDE idiom";
    assert re[0].tier.value == "tier_b" , "realloc on a pointer overwritten by a raw buffer must drop to Tier-B";
}

# ---------------------------------------------------------------------------- #
# §9.5 — list-bound status must MERGE across control flow, not leak in tree    #
# order. A realloc after a branch is Tier-A only if list-bound on EVERY path.  #
# ---------------------------------------------------------------------------- #
test "realloc after a conditional rebind is not provably list-bound (Tier-B)" {
    # arr is list-bound after malloc, but one branch rebinds it to a raw buffer.
    # On the merge the name is list-bound on only one path, so the trailing
    # realloc cannot claim Tier-A regardless of traversal order.
    src = "void *malloc(unsigned int n);\nvoid *realloc(void *p, unsigned int n);\n" + "void *make(int *raw, int n) {\n" + "  int *arr = malloc(n * sizeof(int));\n" + "  if (n > 0) { arr = raw; }\n" + "  arr = realloc(arr, 2 * n * sizeof(int));\n" + "  return arr;\n}\n";
    (jac_str, tags) = transpile_c_str(src, "branch_rebind_realloc.c");
    re = tags.by_idiom(Idiom.REALLOC_ELIDE);
    assert len(re) == 1 , "Expected one REALLOC_ELIDE idiom";
    assert re[0].tier.value == "tier_b" , "realloc after a conditional rebind must be Tier-B (list-bound on only one path)";
}

test "realloc after a branch that never rebinds stays list-bound (Tier-A)" {
    # Neither path touches arr's binding, so the merge preserves list-boundness
    # and the trailing realloc remains a clean Tier-A elide.
    src = "void *malloc(unsigned int n);\nvoid *realloc(void *p, unsigned int n);\n" + "void *make(int n) {\n" + "  int *arr = malloc(n * sizeof(int));\n" + "  if (n > 0) { arr[0] = 1; }\n" + "  arr = realloc(arr, 2 * n * sizeof(int));\n" + "  return arr;\n}\n";
    (jac_str, tags) = transpile_c_str(src, "branch_keep_realloc.c");
    re = tags.by_idiom(Idiom.REALLOC_ELIDE);
    assert len(re) == 1 , "Expected one REALLOC_ELIDE idiom";
    assert re[0].tier.value == "tier_a" , "realloc after a non-rebinding branch should stay Tier-A";
}

test "realloc in a loop that later rebinds the pointer is Tier-B (back-edge)" {
    # On the first iteration arr is the malloc'd list, but the loop body rebinds
    # it to a raw buffer, so on every later iteration the realloc sees a non-list
    # pointer. The kill pre-pass drops arr before the body, yielding Tier-B.
    src = "void *malloc(unsigned int n);\nvoid *realloc(void *p, unsigned int n);\n" + "void *grow(int *raw, int n) {\n" + "  int *arr = malloc(n * sizeof(int));\n" + "  while (n > 0) {\n" + "    arr = realloc(arr, n * sizeof(int));\n" + "    arr = raw;\n" + "    n = n - 1;\n" + "  }\n" + "  return arr;\n}\n";
    (jac_str, tags) = transpile_c_str(src, "loop_rebind_realloc.c");
    re = tags.by_idiom(Idiom.REALLOC_ELIDE);
    assert len(re) == 1 , "Expected one REALLOC_ELIDE idiom";
    assert re[0].tier.value == "tier_b" , "realloc preceding a same-loop rebind must be Tier-B (unsound on the back-edge)";
}
