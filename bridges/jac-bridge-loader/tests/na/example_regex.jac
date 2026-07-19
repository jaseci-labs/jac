# EXAMPLE-PASS metric (north star): the canonical regex "find + replace" example
# must produce the EXACT expected output under BOTH runtimes.
#
# Canonical example (regex README, adapted): compile a pattern, `find` the first
# match (text + span), and do a single literal replacement. `Regex::new` is the
# `new` ctor `Regex(pat)`; `find` -> OwnedMatch (as_str/start/end); the single
# literal replace uses `replacen(hay, 1, rep)` (the &str-Replacer monomorphization,
# na-crossable; `replace_all` with a closure is the callback lane, exercised in the
# conformance vertical, not needed for the README example).
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness { bridge_so, jac_str, llvm_shim, run_na_probe, skip_gate }


glob SO = bridge_so("regex_binder"),
     SHIM = llvm_shim(),
     EXPECTED = ["find = [123] 3..6", "find miss = None", "replacen 1 = [a|b,c]"];


def cpython_side -> list {
    rx = load_bridge(str(SO));
    lines = [];
    r = rx.Regex(r"\d+");
    m = r.find("abc123def");
    lines.append(f"find = [{m.as_str()}] {m.start()}..{m.end()}");
    m.close();
    m2 = r.find("no digits here");
    lines.append("find miss = None" if m2 is None else f"find miss = [{m2.as_str()}]");
    if m2 is not None {
        m2.close();
    }
    r.close();
    s = rx.Regex(r"[,]");
    lines.append(f"replacen 1 = [{s.replacen('a,b,c', 1, '|')}]");
    s.close();
    return lines;
}


def na_side -> list {
    probe = [
        "\nwith entry {",
        f"    r = Regex({jac_str(r'\d+')});",
        f"    m = r.find({jac_str('abc123def')});",
        "    if m is not None {",
        f"        print({jac_str('find = [')} + m.as_str() + {jac_str('] ')} " + f"+ str(m.start()) + {jac_str(
            '..'
        )} + str(m.end()));",
        "        m.close();",
        "    }",
        f"    m2 = r.find({jac_str('no digits here')});",
        "    if m2 is None {",
        f"        print({jac_str('find miss = None')});",
        "    } else {",
        f"        print({jac_str('find miss = [')} + m2.as_str() + {jac_str(']')});",
        "        m2.close();",
        "    }",
        "    r.close();",
        f"    s = Regex({jac_str(r'[,]')});",
        f"    print({jac_str('replacen 1 = [')} " + f"+ s.replacen({jac_str(
            'a,b,c'
        )}, 1, {jac_str('|')}) + {jac_str(']')});",
        "    s.close();",
        "}"
    ];
    return run_na_probe(
        SO, probe, "example_regex.na.jac", "example_regex", strip_blank=True
    );
}


test "example: regex find + replace (golden, na == cpython)" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_side() == EXPECTED;
    assert na_side() == EXPECTED;
}
