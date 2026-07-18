# Full-parity conformance: prove the na and CPython runtimes are observationally
# identical against the SAME libjac_bridge_regex_binder.so - the binder-generated
# bridge for the real `regex` crate at complete-parity coverage (77/96).
#
# This vertical exercises, in one file, every regex-parity lane:
#   * BUILDER CHAIN: `RegexBuilder(pat).case_insensitive(True).build()` - each
#     setter returns the SAME handle (self-identity `&Self`, RC-pinned behind the
#     loader's `rh == self` guard) and `build` is a CROSS-TYPE fallible handle
#     producer (`Result<Regex, Error>` through the `#[jac_error]` channel).
#   * OWNED MATCH: `find` -> OwnedMatch (start/end/as_str), None in-band.
#   * CAPTURES: by index (`get`), by name (`name`), the non-nullable `get_match`
#     (group 0), and `len`.
#   * DRAIN: `split` -> OwnedSplit pulled to exhaustion.
#   * REPLACER &str MONOMORPHIZATION: `replacen(hay, 1, rep)` (Cow -> String).
#   * OPTION<INT>: `shortest_match` -> `int | None` on the null-JacBuf channel.
#   * ITERATOR-OF-STRINGS PARAM: `RegexSetBuilder(patterns)` takes a
#     `Wide<Vec<String>>` (msgpack) - a Python list on CPython, a `jv_array` of
#     `jv_str` on na (the synthesized module inlines the jv codec); then
#     RegexSet `len` + `is_match`.
#
# Regex::is_match is exposed as `matches` (overlay rename).
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness { bridge_so, jac_str, llvm_shim, run_na_probe, skip_gate }


glob SO = bridge_so("regex_binder"),
     SHIM = llvm_shim(),
     # (pattern, haystack) -> matches() on a plain Regex.
     MATCH_CASES = [(r"^ab.$", "abc"), (r"^ab.$", "xbc"), (r"\d+", "a1b22c")],
     # find() observations: text, start, end, or None.
     FIND_CASES = [(r"\d+", "abc123def"), (r"\d+", "no digits")],
     CAPS_PAT = r"(?P<first>\w+) (?P<second>\w+)",
     CAPS_HAY = "hello world",
     SPLIT_HAY = "a,b,,c",
     SET_PATS = ["^a", "b$"],
     SET_HAYS = ["apple", "crab", "neither"];


def cpython_side -> list {
    rx_mod = load_bridge(str(SO));
    lines = [];
    for (pat, hay) in MATCH_CASES {
        r = rx_mod.Regex(pat);
        lines.append(f"matches {repr(pat)} {repr(hay)} = {int(r.matches(hay))}");
        r.close();
    }
    # Builder chain + cross-type fallible build: each setter hands back the SAME
    # underlying handle (self-identity), so the chained wrapper is fully usable.
    b = rx_mod.RegexBuilder("^abc$");
    b2 = b.case_insensitive(True).unicode(True);
    ci = b2.build();
    lines.append(f"builder ci ABC = {int(ci.matches('ABC'))}");
    lines.append(f"builder ci abx = {int(ci.matches('abx'))}");
    ci.close();
    b2.close();
    b.close();
    # find -> OwnedMatch (start/end/as_str) or None.
    for (pat, hay) in FIND_CASES {
        r = rx_mod.Regex(pat);
        m = r.find(hay);
        if m is None {
            lines.append(f"find {repr(pat)} {repr(hay)} = None");
        } else {
            lines.append(
                f"find {repr(pat)} {repr(hay)} = [{m.as_str()}] {m.start()}..{m.end()}"
            );
            m.close();
        }
        r.close();
    }
    # captures: index, name, get_match (group 0), len.
    r = rx_mod.Regex(CAPS_PAT);
    c = r.captures(CAPS_HAY);
    g1 = c.get(1);
    lines.append(f"caps get 1 = [{g1.as_str()}]");
    g1.close();
    nm = c.name("second");
    lines.append(f"caps name second = [{nm.as_str()}]");
    nm.close();
    g0 = c.get_match();
    lines.append(f"caps get_match = [{g0.as_str()}] {g0.start()}..{g0.end()}");
    g0.close();
    lines.append(f"caps len = {c.len()}");
    c.close();
    # split drain, pulled to exhaustion (empty pieces stay distinct from None).
    sp = r"[,]";
    s = rx_mod.Regex(sp);
    d = s.split(SPLIT_HAY);
    i = 0;
    piece = d.next();
    while piece is not None {
        lines.append(f"split {i} = [{piece}]");
        i += 1;
        piece = d.next();
    }
    d.close();
    # replacen: replace only the FIRST comma (the &str-Replacer monomorphization).
    lines.append(f"replacen 1 = [{s.replacen(SPLIT_HAY, 1, '|')}]");
    s.close();
    r.close();
    # shortest_match: Option<usize> in-band None.
    sr = rx_mod.Regex(r"\d+");
    lines.append(f"shortest d+ = {sr.shortest_match('xx123')}");
    lines.append(f"shortest miss = {sr.shortest_match('')}");
    sr.close();
    # RegexSet via the iterator-of-strings builder param.
    sb = rx_mod.RegexSetBuilder(SET_PATS);
    st = sb.build();
    lines.append(f"set len = {st.len()}");
    for hay in SET_HAYS {
        lines.append(f"set is_match {repr(hay)} = {int(st.is_match(hay))}");
    }
    st.close();
    sb.close();
    return [
        ln
        for ln in lines
        if ln.strip()
    ];
}


def na_side -> list {
    probe = ["\nwith entry {"];
    parts = [];
    for (pat, hay) in MATCH_CASES {
        label = f"matches {repr(pat)} {repr(hay)} = ";
        parts.append(f"    r = Regex({jac_str(pat)});");
        parts.append(f"    if r.matches({jac_str(hay)}) {{");
        parts.append(f"        print({jac_str(label + '1')});");
        parts.append("    } else {");
        parts.append(f"        print({jac_str(label + '0')});");
        parts.append("    }");
        parts.append("    r.close();");
    }
    parts.append(f"    b = RegexBuilder({jac_str('^abc$')});");
    parts.append("    b2 = b.case_insensitive(True).unicode(True);");
    parts.append("    ci = b2.build();");
    for hay in ["ABC", "abx"] {
        label = f"builder ci {hay} = ";
        parts.append(f"    if ci.matches({jac_str(hay)}) {{");
        parts.append(f"        print({jac_str(label + '1')});");
        parts.append("    } else {");
        parts.append(f"        print({jac_str(label + '0')});");
        parts.append("    }");
    }
    parts.append("    ci.close();");
    parts.append("    b2.close();");
    parts.append("    b.close();");
    for (pat, hay) in FIND_CASES {
        label = f"find {repr(pat)} {repr(hay)} = ";
        parts.append(f"    r = Regex({jac_str(pat)});");
        parts.append(f"    m = r.find({jac_str(hay)});");
        parts.append("    if m is None {");
        parts.append(f"        print({jac_str(label + 'None')});");
        parts.append("    } else {");
        parts.append(
            f"        print({jac_str(label)} + {jac_str('[')} + m.as_str() + {jac_str(
                ']'
            )} " + f"+ {jac_str(' ')} + str(m.start()) + {jac_str(
                '..'
            )} + str(m.end()));"
        );
        parts.append("        m.close();");
        parts.append("    }");
        parts.append("    r.close();");
    }
    parts.append(f"    r = Regex({jac_str(CAPS_PAT)});");
    parts.append(f"    c = r.captures({jac_str(CAPS_HAY)});");
    parts.append("    g1 = c.get(1);");
    parts.append(
        f"    print({jac_str('caps get 1 = [')} + g1.as_str() + {jac_str(']')});"
    );
    parts.append("    g1.close();");
    parts.append(f"    nm = c.name({jac_str('second')});");
    parts.append(
        f"    print({jac_str('caps name second = [')} + nm.as_str() + {jac_str(']')});"
    );
    parts.append("    nm.close();");
    parts.append("    g0 = c.get_match();");
    parts.append(
        f"    print({jac_str('caps get_match = [')} + g0.as_str() + {jac_str('] ')} " + f"+ str(g0.start()) + {jac_str(
            '..'
        )} + str(g0.end()));"
    );
    parts.append("    g0.close();");
    parts.append(f"    print({jac_str('caps len = ')} + str(c.len()));");
    parts.append("    c.close();");
    parts.append(f"    s = Regex({jac_str(r'[,]')});");
    parts.append(f"    d = s.split({jac_str(SPLIT_HAY)});");
    parts.append("    i = 0;");
    parts.append("    piece = d.next();");
    parts.append("    while piece is not None {");
    parts.append(
        f"        print({jac_str('split ')} + str(i) + {jac_str(' = [')} " + f"+ piece + {jac_str(
            ']'
        )});"
    );
    parts.append("        i += 1;");
    parts.append("        piece = d.next();");
    parts.append("    }");
    parts.append("    d.close();");
    parts.append(
        f"    print({jac_str('replacen 1 = [')} " + f"+ s.replacen({jac_str(
            SPLIT_HAY
        )}, 1, {jac_str('|')}) + {jac_str(']')});"
    );
    parts.append("    s.close();");
    parts.append("    r.close();");
    # Option<int>: print mirrors Python's repr (an int, or the literal None).
    parts.append(f"    sr = Regex({jac_str(r'\d+')});");
    parts.append(f"    sm = sr.shortest_match({jac_str('xx123')});");
    parts.append("    if sm is None {");
    parts.append(f"        print({jac_str('shortest d+ = None')});");
    parts.append("    } else {");
    parts.append(f"        print({jac_str('shortest d+ = ')} + str(sm));");
    parts.append("    }");
    parts.append(f"    s2 = sr.shortest_match({jac_str('')});");
    parts.append("    if s2 is None {");
    parts.append(f"        print({jac_str('shortest miss = None')});");
    parts.append("    } else {");
    parts.append(f"        print({jac_str('shortest miss = ')} + str(s2));");
    parts.append("    }");
    parts.append("    sr.close();");
    # Wide<Vec<String>> param on na: a jv_array of jv_str (dynamic wide document).
    pats_jv = ", ".join([f"jv_str({jac_str(p)})" for p in SET_PATS]);
    parts.append(f"    sb = RegexSetBuilder(jv_array([{pats_jv}]));");
    parts.append("    st = sb.build();");
    parts.append(f"    print({jac_str('set len = ')} + str(st.len()));");
    for hay in SET_HAYS {
        label = f"set is_match {repr(hay)} = ";
        parts.append(f"    if st.is_match({jac_str(hay)}) {{");
        parts.append(f"        print({jac_str(label + '1')});");
        parts.append("    } else {");
        parts.append(f"        print({jac_str(label + '0')});");
        parts.append("    }");
    }
    parts.append("    st.close();");
    parts.append("    sb.close();");
    probe.extend(parts);
    probe.append("}");
    return run_na_probe(SO, probe, "regex_conf.na.jac", "regex_conf", strip_blank=True);
}


test "na cpython regex full-parity conformance" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_side() == na_side();
}
