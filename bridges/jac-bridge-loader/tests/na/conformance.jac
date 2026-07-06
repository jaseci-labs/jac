# M3 conformance: prove the na and CPython runtimes are observationally
# identical against the SAME libjac_bridge_regex.so.
#
# CPython side: the real loader (jaclang.compiler.rust_bridge.load_bridge -> ctypes module).
# na side:      synthesize Jac source from the same .so's metadata, nacompile it
#               with an appended probe that prints one line per assertion outcome,
#               run the binary, and compare the outputs.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness { bridge_so, jac_str, llvm_shim, run_na_probe, skip_gate }


glob SO = bridge_so("regex"),
     SHIM = llvm_shim(),
     CASES = [
         ("foo\\d+", "foo42", True),
         ("foo\\d+", "bar", False),
         ("^[a-z]+$", "hello", True),
         ("^[a-z]+$", "Hello", False),
         ("\\bcat\\b", "the cat sat", True),
         ("\\bcat\\b", "category", False)
     ],
     BAD_PATTERNS = ["(unclosed", "a{", "[z-a]"];


def cpython_side -> list {
    regex = load_bridge(str(SO));
    lines = [];
    for (pat, text, _flag) in CASES {
        re = regex.Regex(pat);
        lines.append(f"match {repr(pat)} {repr(text)} = {int(re.is_match(text))}");
        re.close();
    }
    for pat in BAD_PATTERNS {
        try {
            regex.Regex(pat);
            lines.append(f"bad {repr(pat)} = NOERROR");
        } except Exception as e {
            # Compare the REAL error text, not just "RAISED": the message is the
            # Rust regex crate's own (multi-line) parse error, decoded from the
            # error handle's JacBuf -- the exact path the na JacBuf->str read must
            # reproduce byte-for-byte against the same .so.
            lines.append(f"bad {repr(pat)} = {e}");
        }
    }
    # Normalize multi-line messages the same way the na side does (below), so the
    # two line-lists are structurally comparable.
    return [
        ln
        for ln in "\n".join(lines).splitlines()
        if ln.strip()
    ];
}


def na_side -> list {
    probe = ["\nwith entry {"];
    for (pat, text, _flag) in CASES {
        label = f"match {repr(pat)} {repr(text)} = ";
        probe.append(f"    re = Regex({jac_str(pat)});");
        probe.append(f"    if re.is_match({jac_str(text)}) {{");
        probe.append(f"        print({jac_str(label + '1')});");
        probe.append("    } else {");
        probe.append(f"        print({jac_str(label + '0')});");
        probe.append("    }");
        probe.append("    re.close();");
    }
    for pat in BAD_PATTERNS {
        label = f"bad {repr(pat)} = ";
        # Print the decoded error text (prefix identical to the CPython side), so
        # conformance checks the JacBuf->str message bytes, not merely that it
        # raised.  str(e) on na yields the same Rust message as CPython's {e}.
        probe.append(
            f"    try {{ bad = Regex({jac_str(pat)}); " + f"print({jac_str(
                label + 'NOERROR'
            )}); }} " + f"except Exception as e {{ print({jac_str(label)} + str(e)); }}"
        );
    }
    probe.append("}");
    return run_na_probe(SO, probe, "conf.jac", "conf", strip_blank=True);
}


test "na cpython conformance" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_side() == na_side();
}
