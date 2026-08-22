"""Pin the literal JS host global sets to JS_HOST_GLOBAL_TAGS.

The sets in jac0core/constant.jac are hand-written literals because glob-scope
frozenset() calls and comprehensions are not native-lowerable. This test is the
drift guard: edit the TAGS table, then update the literals (or vice versa) --
one must never move without the other.
"""

import from jaclang.jac0core.constant {
    BROWSER_SEED_GLOBALS,
    JS_HOST_AMBIENT_GLOBALS,
    JS_HOST_CONSTRUCTORS,
    JS_HOST_GLOBAL_TAGS
}

test "literal JS host global sets stay in sync with JS_HOST_GLOBAL_TAGS" {
    derived_seed = set();
    derived_ctors = set();
    for kv in JS_HOST_GLOBAL_TAGS.items() {
        nm = kv[0];
        tags = kv[1];
        if tags[2] {
            derived_seed.add(nm);
        }
        if tags[1] == "ctor" {
            derived_ctors.add(nm);
        }
    }

    assert BROWSER_SEED_GLOBALS == frozenset(derived_seed) , (
        "BROWSER_SEED_GLOBALS drifted from JS_HOST_GLOBAL_TAGS: only in set: "
        + str(sorted(BROWSER_SEED_GLOBALS - frozenset(derived_seed)))
        + "; only in tags: "
        + str(sorted(frozenset(derived_seed) - BROWSER_SEED_GLOBALS))
    );
    assert JS_HOST_CONSTRUCTORS == frozenset(derived_ctors) , (
        "JS_HOST_CONSTRUCTORS drifted from JS_HOST_GLOBAL_TAGS: only in set: "
        + str(sorted(JS_HOST_CONSTRUCTORS - frozenset(derived_ctors)))
        + "; only in tags: "
        + str(sorted(frozenset(derived_ctors) - JS_HOST_CONSTRUCTORS))
    );
    assert JS_HOST_AMBIENT_GLOBALS == frozenset(JS_HOST_GLOBAL_TAGS.keys()) , (
        "JS_HOST_AMBIENT_GLOBALS drifted from JS_HOST_GLOBAL_TAGS keys"
    );
}
