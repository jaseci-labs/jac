# Owning-wrapper conformance: prove the na and CPython runtimes are
# observationally identical for the nullable Option<Ref> surface, against the
# SAME libjac_bridge_owning.so.
#
# na side: synthesize Jac source from the .so's metadata, nacompile it with an
# appended probe that prints one line per observation, run the binary, diff the
# output against the CPython loader.  Gated on the LLVM shim; skips without it.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness { bridge_so, jac_str, llvm_shim, run_na_probe, skip_gate }


glob SO = bridge_so("owning"),
     SHIM = llvm_shim(),
     # (pattern, haystack) -> find() text or None; brackets make "" vs None visible.
     FIND_CASES = [
         (r"\d+", "abc123def"),
         (r"\d+", "no digits"),
         (r"", "anything"),
         (r"\w+", "hello world")
     ],
     # (pattern, haystack, group) -> captures().name(group): text / "" / None.
     CAPS_CASES = [
         (r"(?P<num>\d+)-(?P<rest>\d+)", "nothing here", "num"),
         (r"(?P<num>\d+)-(?P<rest>\d+)", "12-34 today", "num"),
         (r"(?P<num>\d+)-(?P<rest>\d+)", "12-34 today", "nope"),
         (r"(?P<a>x)?(?P<b>y)", "y", "a"),
         (r"(?P<z>\d*)", "abc", "z")
     ],
     # (pattern, haystack, group) -> captures().name_match(group).as_str(): the NESTED
     # wrapper path (a Captures produces a Match).
     NAME_MATCH_CASES = [
         (r"(?P<num>\d+)-(?P<rest>\d+)", "12-34 today", "num"),
         (r"(?P<num>\d+)-(?P<rest>\d+)", "12-34 today", "nope"),
         (r"(?P<a>x)?(?P<b>y)", "y", "a"),
         (r"(?P<num>\d+)", "nothing here", "num"),
         (r"(?P<z>\d*)", "abc", "z")
     ],
     # (pattern, haystack) -> find_iter cursor drained to exhaustion.
     CURSOR_CASES = [
         (r"\d+", "a1 b22 c333"),
         (r"\d+", "no digits at all"),
         (r"\w+", "hi there world"),
         (r"x", "")
     ],
     # (pattern, haystack) -> split drain cursor exhausted.
     SPLIT_CASES = [
         (r",\s*", "a, bb,ccc"),
         (r"-", "x-y-z"),
         (r"\d+", "no numbers here"),
         (r"\d+", "1a2b3")
     ],
     # (pattern, haystack) -> replace_all driven by the "upper" callback.
     REPLACE_UPPER_CASES = [
         (r"[a-z]+", "hello world"),
         (r"\w+", "MixEd caSe x"),
         (r"z+", "no zeds here"),
         (r"\w+", "")
     ],
     # (pattern, haystack) -> replace_all driven by a SECOND callback that wraps in <>.
     REPLACE_BRACKET_CASES = [
         (r"\d+", "a1b22c333"),
         (r"-", "x-y-z"),
         (r"\d+", "no digits")
     ],
     # (pattern, haystack, prefix) -> replace_all driven by a CAPTURING closure
     # (`lambda m : prefix + m`) — proves the {call, ctx} env crosses to Rust.
     REPLACE_CAPTURE_CASES = [
         (r"\w+", "hello world", ">>"),
         (r"\d+", "a1b2c3", "#"),
         (r"z+", "no zeds here", "X")
     ];


def _replace_label(pat: str, text: str, kind: str) -> str {
    return f"replace {repr(pat)} {repr(text)} {kind} = ";
}


def _cursor_label(pat: str, text: str) -> str {
    return f"iter {repr(pat)} {repr(text)} = ";
}


def _split_label(pat: str, text: str) -> str {
    return f"split {repr(pat)} {repr(text)} = ";
}


def _find_label(pat: str, text: str) -> str {
    return f"find {repr(pat)} {repr(text)} = ";
}


def _caps_label(pat: str, text: str, group: str) -> str {
    return f"caps {repr(pat)} {repr(text)} name({repr(group)}) = ";
}


def _nm_label(pat: str, text: str, group: str) -> str {
    return f"nmatch {repr(pat)} {repr(text)} name_match({repr(group)}) = ";
}


def cpython_side -> list {
    owning = load_bridge(str(SO));
    lines = [];
    for case in FIND_CASES {
        pat = case[0];
        text = case[1];
        re = owning.Regex(pat);
        m = re.find(text);
        if m is None {
            lines.append(_find_label(pat, text) + "None");
        } else {
            lines.append(_find_label(pat, text) + "[" + m.as_str() + "]");
            m.close();
        }
        re.close();
    }
    for case in CAPS_CASES {
        pat = case[0];
        text = case[1];
        group = case[2];
        label = _caps_label(pat, text, group);
        re = owning.Regex(pat);
        c = re.captures(text);
        if c is None {
            lines.append(label + "caps=None");
        } else {
            v = c.name(group);
            if v is None {
                lines.append(label + "None");
            } else {
                lines.append(label + "[" + v + "]");
            }
            c.close();
        }
        re.close();
    }
    for case in NAME_MATCH_CASES {
        pat = case[0];
        text = case[1];
        group = case[2];
        label = _nm_label(pat, text, group);
        re = owning.Regex(pat);
        c = re.captures(text);
        if c is None {
            lines.append(label + "caps=None");
        } else {
            mm = c.name_match(group);
            if mm is None {
                lines.append(label + "None");
            } else {
                lines.append(label + "[" + mm.as_str() + "]");
                mm.close();
            }
            c.close();
        }
        re.close();
    }
    for case in CURSOR_CASES {
        pat = case[0];
        text = case[1];
        re = owning.Regex(pat);
        cur = re.find_iter(text);
        acc = "";
        m = cur.next();
        while m is not None {
            acc = acc + m.as_str() + "|";
            m.close();
            m = cur.next();
        }
        lines.append(_cursor_label(pat, text) + "[" + acc + "]");
        cur.close();
        re.close();
    }
    for case in SPLIT_CASES {
        pat = case[0];
        text = case[1];
        re = owning.Regex(pat);
        dr = re.split(text);
        acc = "";
        s = dr.next();
        while s is not None {
            acc = acc + s + "|";
            s = dr.next();
        }
        lines.append(_split_label(pat, text) + "[" + acc + "]");
        dr.close();
        re.close();
    }
    for case in REPLACE_UPPER_CASES {
        pat = case[0];
        text = case[1];
        re = owning.Regex(pat);
        out = re.replace_all(text, lambda (m: str) -> str { m.upper(); });
        lines.append(_replace_label(pat, text, "upper") + "[" + out + "]");
        re.close();
    }
    for case in REPLACE_BRACKET_CASES {
        pat = case[0];
        text = case[1];
        re = owning.Regex(pat);
        out = re.replace_all(text, lambda (m: str) -> str { "<" + m + ">"; });
        lines.append(_replace_label(pat, text, "bracket") + "[" + out + "]");
        re.close();
    }
    for case in REPLACE_CAPTURE_CASES {
        pat = case[0];
        text = case[1];
        prefix = case[2];
        re = owning.Regex(pat);
        out = re.replace_all(text, lambda (m: str) -> str { prefix + m; });
        lines.append(_replace_label(pat, text, "capture") + "[" + out + "]");
        re.close();
    }
    return [
        ln
        for ln in "\n".join(lines).splitlines()
        if ln.strip()
    ];
}


def na_side -> list {
    # The callback crosses as a real Jac lambda: the na backend lowers it to a
    # ctx-leading C-ABI trampoline + a {call, ctx} record at the call site (no
    # hand-written def:pub thunk — that is the whole point of this vertical).
    probe = ["\nwith entry {"];
    for case in FIND_CASES {
        pat = case[0];
        text = case[1];
        label = _find_label(pat, text);
        probe.append("    re = Regex(" + jac_str(pat) + ");");
        probe.append("    m = re.find(" + jac_str(text) + ");");
        probe.append("    if m is not None {");
        probe.append("        om: OwnedMatch = m;");
        probe.append(
            "        print(" + jac_str(label + "[") + " + om.as_str() + " + jac_str(
                "]"
            ) + ");"
        );
        probe.append("        om.close();");
        probe.append("    } else {");
        probe.append("        print(" + jac_str(label + "None") + ");");
        probe.append("    }");
        probe.append("    re.close();");
    }
    for case in CAPS_CASES {
        pat = case[0];
        text = case[1];
        group = case[2];
        label = _caps_label(pat, text, group);
        probe.append("    re = Regex(" + jac_str(pat) + ");");
        probe.append("    c = re.captures(" + jac_str(text) + ");");
        probe.append("    if c is not None {");
        probe.append("        oc: OwnedCaptures = c;");
        probe.append("        n = oc.name(" + jac_str(group) + ");");
        probe.append("        if n is not None {");
        probe.append(
            "            print(" + jac_str(label + "[") + " + n + " + jac_str("]") + ");"
        );
        probe.append("        } else {");
        probe.append("            print(" + jac_str(label + "None") + ");");
        probe.append("        }");
        probe.append("        oc.close();");
        probe.append("    } else {");
        probe.append("        print(" + jac_str(label + "caps=None") + ");");
        probe.append("    }");
        probe.append("    re.close();");
    }
    for case in NAME_MATCH_CASES {
        pat = case[0];
        text = case[1];
        group = case[2];
        label = _nm_label(pat, text, group);
        probe.append("    re = Regex(" + jac_str(pat) + ");");
        probe.append("    c = re.captures(" + jac_str(text) + ");");
        probe.append("    if c is not None {");
        probe.append("        oc: OwnedCaptures = c;");
        probe.append("        mm = oc.name_match(" + jac_str(group) + ");");
        probe.append("        if mm is not None {");
        probe.append("            om2: OwnedMatch = mm;");
        probe.append(
            "            print(" + jac_str(label + "[") + " + om2.as_str() + " + jac_str(
                "]"
            ) + ");"
        );
        probe.append("            om2.close();");
        probe.append("        } else {");
        probe.append("            print(" + jac_str(label + "None") + ");");
        probe.append("        }");
        probe.append("        oc.close();");
        probe.append("    } else {");
        probe.append("        print(" + jac_str(label + "caps=None") + ");");
        probe.append("    }");
        probe.append("    re.close();");
    }
    for case in CURSOR_CASES {
        pat = case[0];
        text = case[1];
        label = _cursor_label(pat, text);
        probe.append("    re = Regex(" + jac_str(pat) + ");");
        probe.append("    cur = re.find_iter(" + jac_str(text) + ");");
        probe.append("    acc = \"\";");
        probe.append("    m = cur.next();");
        probe.append("    while m is not None {");
        probe.append("        om: OwnedMatch = m;");
        probe.append("        acc = acc + om.as_str() + \"|\";");
        probe.append("        om.close();");
        probe.append("        m = cur.next();");
        probe.append("    }");
        probe.append(
            "    print(" + jac_str(label + "[") + " + acc + " + jac_str("]") + ");"
        );
        probe.append("    cur.close();");
        probe.append("    re.close();");
    }
    for case in SPLIT_CASES {
        pat = case[0];
        text = case[1];
        label = _split_label(pat, text);
        probe.append("    re = Regex(" + jac_str(pat) + ");");
        probe.append("    dr = re.split(" + jac_str(text) + ");");
        probe.append("    acc = \"\";");
        probe.append("    s = dr.next();");
        probe.append("    while s is not None {");
        probe.append("        acc = acc + s + \"|\";");
        probe.append("        s = dr.next();");
        probe.append("    }");
        probe.append(
            "    print(" + jac_str(label + "[") + " + acc + " + jac_str("]") + ");"
        );
        probe.append("    dr.close();");
        probe.append("    re.close();");
    }
    for case in REPLACE_UPPER_CASES {
        pat = case[0];
        text = case[1];
        label = _replace_label(pat, text, "upper");
        probe.append("    re = Regex(" + jac_str(pat) + ");");
        probe.append(
            "    out = re.replace_all(" + jac_str(text) + ", lambda (m: str) -> str { m.upper(); });"
        );
        probe.append(
            "    print(" + jac_str(label + "[") + " + out + " + jac_str("]") + ");"
        );
        probe.append("    re.close();");
    }
    for case in REPLACE_BRACKET_CASES {
        pat = case[0];
        text = case[1];
        label = _replace_label(pat, text, "bracket");
        probe.append("    re = Regex(" + jac_str(pat) + ");");
        probe.append(
            "    out = re.replace_all(" + jac_str(text) + ", lambda (m: str) -> str { \"<\" + m + \">\"; });"
        );
        probe.append(
            "    print(" + jac_str(label + "[") + " + out + " + jac_str("]") + ");"
        );
        probe.append("    re.close();");
    }
    # A CAPTURING closure only "captures" when its free var is a FUNCTION local
    # (a `with entry` local is module-scoped, hence not a capture), so each capture
    # case lives in its own `def` helper — the na backend then threads `prefix`
    # through the {call, ctx} env.  Helpers are emitted before `with entry`.
    cap_helpers: list = [];
    for (i, case) in enumerate(REPLACE_CAPTURE_CASES) {
        pat = case[0];
        text = case[1];
        prefix = case[2];
        label = _replace_label(pat, text, "capture");
        fname = f"_cap_case_{i}";
        cap_helpers.append("def " + fname + "() -> str {");
        cap_helpers.append("    prefix = " + jac_str(prefix) + ";");
        cap_helpers.append("    re = Regex(" + jac_str(pat) + ");");
        cap_helpers.append(
            "    out = re.replace_all(" + jac_str(text) + ", lambda (m: str) -> str { prefix + m; });"
        );
        cap_helpers.append("    re.close();");
        cap_helpers.append("    return out;");
        cap_helpers.append("}");
        probe.append(
            "    print(" + jac_str(label + "[") + " + " + fname + "() + " + jac_str(
                "]"
            ) + ");"
        );
    }
    probe.append("}");
    extra = "\n".join(cap_helpers) + "\n";
    return run_na_probe(
        SO,
        probe,
        "owning_conf.na.jac",
        "owning_conf",
        extra_src=extra,
        strip_blank=True
    );
}


test "owning na cpython conformance" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_side() == na_side();
}
