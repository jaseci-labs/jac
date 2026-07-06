# Vec->list conformance: prove the na and CPython runtimes return observationally
# identical list[V] values for the Vec return tag (TAG_LIST_BIT | value_tag),
# against the SAME libjac_bridge_list.so.
#
# na side: synthesize Jac source from the .so metadata, append a probe that prints
# one canonical line per element (in order -- lists are ordered), nacompile, run,
# and diff against the CPython loader. Gated on the LLVM shim; skips without it.
#
# Width note: na's `int` is 64-bit SIGNED, so a `u64` with the high bit set is
# carried as its two's-complement signed image (u64::MAX -> -1). The CPython side
# is normalized to that image (`norm_unsigned`) before comparison, so the SAME 64 bits are
# what cross on both runtimes.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness {
    bridge_so,
    canon_value,
    jac_str,
    llvm_shim,
    run_na_probe,
    skip_gate
}


glob SO = bridge_so("list"),
     SHIM = llvm_shim(),
     SEED = 3,
     # (method, element-kind). Order matters: lists are compared in element order.
     METHODS = [
         ("counts", "int"),
         ("big", "uint"),
         ("labels", "str"),
         ("flags", "bool"),
         ("none", "int"),
         ("checked", "uint")
     ];


def cpython_side -> list {
    mod = load_bridge(str(SO));
    store = mod.Store(SEED);
    lines = [];
    for case in METHODS {
        method = case[0];
        kind = case[1];
        lines.append("# " + method);
        fn = getattr(store, method);
        for x in fn() {
            lines.append(canon_value(x, kind));
        }
    }
    store.close();
    return lines;
}


def na_side -> list {
    probe = ["\nwith entry {", f"    s = Store({SEED});"];
    for case in METHODS {
        method = case[0];
        kind = case[1];
        # A distinct local per method: na types a local by its first assignment,
        # so reusing one name across list[int]/list[str]/list[bool] would clash.
        probe.append("    print(" + jac_str("# " + method) + ");");
        probe.append(f"    _lst_{method} = s.{method}();");
        probe.append(f"    for x in _lst_{method} {{");
        if kind == "bool" {
            probe.append("        print(\"1\" if x else \"0\");");
        } else {
            probe.append("        print(str(x));");
        }
        probe.append("    }");
    }
    probe.append("    s.close();");
    probe.append("}");
    return run_na_probe(SO, probe, "list_conf.na.jac", "list_conf");
}


test "list na cpython conformance" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_side() == na_side();
}
