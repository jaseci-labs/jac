# HashMap->dict conformance: prove the na and CPython runtimes return
# observationally identical dict[str, V] values for the map return tag
# (TAG_MAP_BIT | value_tag), against the SAME libjac_bridge_map.so.
#
# na side: synthesize Jac source from the .so metadata, append a probe that prints
# one "method|key|value" line per entry, nacompile, run, and diff against the
# CPython loader. Dict iteration order is unspecified on both runtimes, so BOTH
# sides sort their line lists before comparison. Gated on the LLVM shim.
#
# Width note: na's `int` is 64-bit SIGNED; a `u64` with the high bit set crosses as
# its two's-complement signed image (u64::MAX -> -1). The CPython side normalizes to
# that image (`norm_unsigned`) before comparison.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness {
    bridge_so,
    canon_value,
    jac_str,
    llvm_shim,
    run_na_probe,
    skip_gate
}


glob SO = bridge_so("map"),
     SHIM = llvm_shim(),
     SEED = 3,
     # (method, value-kind). Compared as a sorted set of key=value lines.
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
        fn = getattr(store, method);
        d = fn();
        for k in d {
            lines.append(method + "|" + k + "|" + canon_value(d[k], kind));
        }
    }
    store.close();
    return sorted(lines);
}


def na_side -> list {
    probe = ["\nwith entry {", f"    s = Store({SEED});"];
    for case in METHODS {
        method = case[0];
        kind = case[1];
        # A distinct local per method: na types a local by its first assignment,
        # so reusing one name across dict[str,int]/dict[str,str]/dict[str,bool]
        # would clash.
        _dv = f"_map_{method}";
        probe.append(f"    {_dv} = s.{method}();");
        probe.append(f"    for k in {_dv} {{");
        if kind == "bool" {
            probe.append(
                "        print(" + jac_str(method + "|") + " + k + \"|\" + (\"1\" if " + _dv + "[k] else \"0\"));"
            );
        } elif kind == "str" {
            probe.append(
                "        print(" + jac_str(method + "|") + " + k + \"|\" + " + _dv + "[k]);"
            );
        } else {
            probe.append(
                "        print(" + jac_str(method + "|") + " + k + \"|\" + str(" + _dv + "[k]));"
            );
        }
        probe.append("    }");
    }
    probe.append("    s.close();");
    probe.append("}");
    return run_na_probe(SO, probe, "map_conf.na.jac", "map_conf", sort_lines=True);
}


test "map na cpython conformance" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_side() == na_side();
}
