# Async conformance (M6.3): prove the na and CPython runtimes are observationally
# identical for an async-fn bridge, against the SAME libjac_bridge_async.so.
#
# Async is ABI-transparent to the loaders: the #[bridge] macro wraps each future
# in a blocking C shim (block_on on a module-owned Tokio runtime), so na and
# CPython both call an exported C symbol and read status + out-params exactly as
# for a sync bridge. This vertical exercises that the async round-trip composes
# with every marshaling flavor already proven for sync bridges: a signed return
# (seed), a String return (label), a fallible int return (checked_div, incl. the
# error path), and a Vec<i64>->list return (counts).
#
# na side: synthesize Jac source from the .so metadata, append a probe that prints
# one canonical line per observation, nacompile against the real .so, run, and
# diff against the CPython loader. Gated on the LLVM shim; skips without it.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness {
    bridge_so,
    jac_str,
    llvm_shim,
    na_int_literal,
    run_na_probe,
    skip_gate
}


glob SO = bridge_so("async"),
     SHIM = llvm_shim(),
     SEED = 6,
     LABEL = "async-demo";


def cpython_side -> list {
    mod = load_bridge(str(SO));
    err_cls = mod.AsyncError;
    c = mod.AsyncCalc(SEED, LABEL);
    lines = [];
    lines.append("seed = " + str(c.seed()));
    lines.append("label = " + str(c.label()));
    lines.append("div(4) = " + str(c.checked_div(4)));
    try {
        c.checked_div(0);
        lines.append("div(0) = ?");
    } except err_cls {
        lines.append("div(0) = ERR");
    }
    lines.append("# counts");
    for x in c.counts(3) {
        lines.append(str(x));
    }
    c.close();
    return lines;
}


def na_side -> list {
    probe = ["\nwith entry {"];
    probe.append(
        "    c = AsyncCalc(" + na_int_literal(SEED) + ", " + jac_str(LABEL) + ");"
    );
    probe.append("    print(" + jac_str("seed = ") + " + str(c.seed()));");
    probe.append("    print(" + jac_str("label = ") + " + str(c.label()));");
    probe.append("    print(" + jac_str("div(4) = ") + " + str(c.checked_div(4)));");
    probe.append("    try {");
    probe.append("        r = c.checked_div(0);");
    probe.append("        print(" + jac_str("div(0) = ?") + ");");
    probe.append("    } except Exception {");
    probe.append("        print(" + jac_str("div(0) = ERR") + ");");
    probe.append("    }");
    probe.append("    print(" + jac_str("# counts") + ");");
    probe.append("    _cnt = c.counts(3);");
    probe.append("    for x in _cnt {");
    probe.append("        print(str(x));");
    probe.append("    }");
    probe.append("    c.close();");
    probe.append("}");
    return run_na_probe(SO, probe, "async_conf.na.jac", "async_conf", strip_blank=True);
}


test "async na cpython conformance" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_side() == na_side();
}
