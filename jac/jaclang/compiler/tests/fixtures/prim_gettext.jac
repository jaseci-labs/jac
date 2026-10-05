"""Bundled native `gettext` cross-backend equivalence fixture (#6978).

The same `import gettext` binds CPython's `gettext` on the sv backend and
`na_stdlib/gettext.jac` on the na (native LLVM) backend. No `.mo` catalogue is
needed for the parts pinned here: the `NullTranslations` passthrough plus its
fallback chain, `textdomain`/`bindtextdomain` state, the module-level
`gettext`/`ngettext` (which fall back to the msgid when no catalogue is found),
and the C plural-form expression engine -- CPython compiles it to a lambda via
`c2py`, the native module parses it to an AST evaluated by `_peval`, so the
lanes call their own entry point and compare the resulting plural indices.
Per-lane bodies (never a shared helper) because a dict cannot cross the
native->Python call boundary. ES/JS opts out.
"""

import gettext;


def gettext_py -> dict[any, any] {
    t = gettext.NullTranslations();
    passthrough = t.gettext("hello");
    n1 = t.ngettext("one", "many", 1);
    n2 = t.ngettext("one", "many", 5);
    ctx = t.pgettext("menu", "Open");
    nctx = t.npgettext("menu", "file", "files", 3);
    fb = gettext.NullTranslations();
    t.add_fallback(fb);
    chained = t.gettext("chained");
    dom0 = gettext.textdomain();
    dom1 = gettext.textdomain("myapp");
    dom2 = gettext.textdomain();
    bound = gettext.bindtextdomain("myapp", "/tmp/locale-does-not-exist");
    mod_g = gettext.gettext("missing");
    mod_n1 = gettext.ngettext("apple", "apples", 1);
    mod_n2 = gettext.ngettext("apple", "apples", 4);
    germanic = gettext.c2py("n != 1");
    plural_1 = germanic(1);
    plural_2 = germanic(2);
    slavic = gettext.c2py(
        "n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 &&"
        " (n%100<10 || n%100>=20) ? 1 : 2"
    );
    sl_1 = slavic(1);
    sl_3 = slavic(3);
    sl_11 = slavic(11);
    zero = gettext.c2py("0");
    zero_5 = zero(5);
    nested = gettext.c2py("(n > 1) + (n > 10)");
    nested_11 = nested(11);
    bad = "";
    try {
        gettext.c2py("n $ 1");
    } except Exception as e {
        bad = "ERR";
    }
    expanded = gettext._expand_lang("en_US.UTF-8");
    return {
        "passthrough": passthrough,
        "n1": n1,
        "n2": n2,
        "ctx": ctx,
        "nctx": nctx,
        "chained": chained,
        "dom0": dom0,
        "dom1": dom1,
        "dom2": dom2,
        "bound": bound,
        "mod_g": mod_g,
        "mod_n1": mod_n1,
        "mod_n2": mod_n2,
        "plural_1": plural_1,
        "plural_2": plural_2,
        "sl_1": sl_1,
        "sl_3": sl_3,
        "sl_11": sl_11,
        "zero_5": zero_5,
        "nested_11": nested_11,
        "bad": bad,
        "expanded_len": len(expanded),
        "expanded_first": expanded[0],
        "expanded_last": expanded[len(expanded) - 1],

    };
}


def gettext_cl -> dict[any, any] {
    return {};
}


def gettext_na -> dict[str, any] {
    t = gettext.NullTranslations();
    passthrough = t.gettext("hello");
    n1 = t.ngettext("one", "many", 1);
    n2 = t.ngettext("one", "many", 5);
    ctx = t.pgettext("menu", "Open");
    nctx = t.npgettext("menu", "file", "files", 3);
    fb = gettext.NullTranslations();
    t.add_fallback(fb);
    chained = t.gettext("chained");
    dom0 = gettext.textdomain();
    dom1 = gettext.textdomain("myapp");
    dom2 = gettext.textdomain();
    bound = gettext.bindtextdomain("myapp", "/tmp/locale-does-not-exist");
    mod_g = gettext.gettext("missing");
    mod_n1 = gettext.ngettext("apple", "apples", 1);
    mod_n2 = gettext.ngettext("apple", "apples", 4);
    germanic = gettext.c2py_ast("n != 1");
    plural_1 = gettext.plural_index(germanic, 1);
    plural_2 = gettext.plural_index(germanic, 2);
    slavic = gettext.c2py_ast(
        "n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 &&"
        " (n%100<10 || n%100>=20) ? 1 : 2"
    );
    sl_1 = gettext.plural_index(slavic, 1);
    sl_3 = gettext.plural_index(slavic, 3);
    sl_11 = gettext.plural_index(slavic, 11);
    zero = gettext.c2py_ast("0");
    zero_5 = gettext.plural_index(zero, 5);
    nested = gettext.c2py_ast("(n > 1) + (n > 10)");
    nested_11 = gettext.plural_index(nested, 11);
    bad = "";
    try {
        gettext.c2py_ast("n $ 1");
    } except Exception as e {
        bad = "ERR";
    }
    expanded = gettext._expand_lang("en_US.UTF-8");
    return {
        "passthrough": passthrough,
        "n1": n1,
        "n2": n2,
        "ctx": ctx,
        "nctx": nctx,
        "chained": chained,
        "dom0": dom0,
        "dom1": dom1,
        "dom2": dom2,
        "bound": bound,
        "mod_g": mod_g,
        "mod_n1": mod_n1,
        "mod_n2": mod_n2,
        "plural_1": plural_1,
        "plural_2": plural_2,
        "sl_1": sl_1,
        "sl_3": sl_3,
        "sl_11": sl_11,
        "zero_5": zero_5,
        "nested_11": nested_11,
        "bad": bad,
        "expanded_len": len(expanded),
        "expanded_first": expanded[0],
        "expanded_last": expanded[len(expanded) - 1],

    };
}
