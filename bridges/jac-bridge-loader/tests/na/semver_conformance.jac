# Seed-crate conformance: prove the na and CPython runtimes are observationally
# identical against the SAME libjac_bridge_semver.so — the binder-generated bridge
# for the real `semver` crate (with its `treat_as = "opaque"` overlay).
#
# This is the first vertical to exercise the INBOUND HANDLE PARAM lane: a method
# argument that is a reference to ANOTHER bridged handle (two bridged types
# interacting). `Version.cmp(other)` and `VersionReq.matches(version)` each take a
# `&Version` — the caller passes that object's handle, which the shim reconstructs
# on the Rust side. Both runtimes must marshal that handle identically.
#
# It also exercises the FULL-PARITY synth lanes (no overlay inject): the Display
# lane (`to_string`), the Ord lane (`cmp`, -1/0/1), and the opaque field-reader
# lane — scalar readers (`major`/`minor`/`patch`), a HANDLE reader (`Version.pre ->
# Prerelease`, a produced handle whose `to_string` is read), and a FIELDLESS-ENUM
# reader (`Comparator.op -> String`). `Comparator` is forced opaque too, so its
# `parse` ctor / `matches` / `op` / `major` all cross, and its `minor`/`patch`
# `Option<u64>` fields exercise the OPTION<INT> lane (Some as an 8-byte JacBuf,
# None as a null pointer) on both runtimes ("~1.2" has Some(2)/None; "^1" has
# None/None; "<3.0.0" has Some(0)/Some(0)).
#
# The `#[jac(assoc)]` statics (`Version.parse`, and the `from_str` FromStr family)
# are na-gated, so they are intentionally NOT exercised here — a static cannot cross
# on na, so it cannot participate in a dual-runtime identity check. Construction uses
# only ctors that exist on BOTH runtimes: `Version(major, minor, patch)` (the `new`
# ctor), `VersionReq(req)` and `Comparator(req)` (each a `parse` ctor).
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness { bridge_so, jac_str, llvm_shim, run_na_probe, skip_gate }


glob SO = bridge_so("semver"),
     SHIM = llvm_shim(),
     # (major, minor, patch) triples constructed on both sides.
     VERSIONS = [(1, 2, 3), (1, 3, 0), (1, 0, 0), (2, 0, 0)],
     # (requirement, index-into-VERSIONS) — matches() against a handle arg.
     REQ_CASES = [(">=1.2.0", 0), (">=1.2.0", 2), ("^1", 3), ("^1", 1)],
     # comparator strings — parse ctor + op (enum-name reader) + major + matches.
     COMP_CASES = [">=1.2.0", "^1", "~2.3", "<3.0.0"];


def cpython_side -> list {
    semver = load_bridge(str(SO));
    lines = [];
    vers = [semver.Version(a, b, c) for (a, b, c) in VERSIONS];
    # Scalar field-reader lane (public major/minor/patch).
    for (i, v) in enumerate(vers) {
        lines.append(f"fields {i} = {v.major()}.{v.minor()}.{v.patch()}");
    }
    # Display lane: to_string.
    for (i, v) in enumerate(vers) {
        lines.append(f"tostr {i} = {v.to_string()}");
    }
    # Handle field-reader lane: Version.pre -> Prerelease handle, read via to_string.
    for (i, v) in enumerate(vers) {
        p = v.pre();
        lines.append(f"pre {i} = {p.to_string()}");
        p.close();
    }
    # cmp — a HANDLE PARAM (`other: &Version`), yields -1 / 0 / 1 (Ord lane).
    lines.append(f"cmp 0 1 = {vers[0].cmp(vers[1])}");
    lines.append(f"cmp 1 0 = {vers[1].cmp(vers[0])}");
    lines.append(f"cmp 0 0 = {vers[0].cmp(vers[0])}");
    lines.append(f"cmp 3 0 = {vers[3].cmp(vers[0])}");
    # matches — a HANDLE PARAM (`version: &Version`), yields a bool.
    for (req, vi) in REQ_CASES {
        r = semver.VersionReq(req);
        lines.append(f"matches {repr(req)} {vi} = {int(r.matches(vers[vi]))}");
        r.close();
    }
    # Comparator (forced opaque): parse ctor, op enum-name reader, major, matches.
    for (ci, cstr) in enumerate(COMP_CASES) {
        c = semver.Comparator(cstr);
        lines.append(f"comp {ci} op = {c.op()}");
        lines.append(f"comp {ci} major = {c.major()}");
        lines.append(f"comp {ci} minor = {c.minor()}");
        lines.append(f"comp {ci} patch = {c.patch()}");
        lines.append(f"comp {ci} m0 = {int(c.matches(vers[0]))}");
        c.close();
    }
    for v in vers {
        v.close();
    }
    return [
        ln
        for ln in lines
        if ln.strip()
    ];
}


def na_side -> list {
    probe = ["\nwith entry {"];
    parts = [];
    for (i, (a, b, c)) in enumerate(VERSIONS) {
        parts.append(f"    v{i} = Version({a}, {b}, {c});");
    }
    for (i, _v) in enumerate(VERSIONS) {
        label = f"fields {i} = ";
        parts.append(
            f"    print({jac_str(label)} + str(v{i}.major()) + {jac_str('.')} " + f"+ str(v{i}.minor()) + {jac_str(
                '.'
            )} + str(v{i}.patch()));"
        );
    }
    for (i, _v) in enumerate(VERSIONS) {
        label = f"tostr {i} = ";
        parts.append(f"    print({jac_str(label)} + v{i}.to_string());");
    }
    for (i, _v) in enumerate(VERSIONS) {
        label = f"pre {i} = ";
        parts.append(f"    p{i} = v{i}.pre();");
        parts.append(f"    print({jac_str(label)} + p{i}.to_string());");
        parts.append(f"    p{i}.close();");
    }
    for (ai, bi) in [(0, 1), (1, 0), (0, 0), (3, 0)] {
        label = f"cmp {ai} {bi} = ";
        parts.append(f"    print({jac_str(label)} + str(v{ai}.cmp(v{bi})));");
    }
    for (req, vi) in REQ_CASES {
        label = f"matches {repr(req)} {vi} = ";
        parts.append(f"    r = VersionReq({jac_str(req)});");
        parts.append(f"    if r.matches(v{vi}) {{");
        parts.append(f"        print({jac_str(label + '1')});");
        parts.append("    } else {");
        parts.append(f"        print({jac_str(label + '0')});");
        parts.append("    }");
        parts.append("    r.close();");
    }
    for (ci, cstr) in enumerate(COMP_CASES) {
        parts.append(f"    c = Comparator({jac_str(cstr)});");
        parts.append(f"    print({jac_str(f'comp {ci} op = ')} + c.op());");
        parts.append(f"    print({jac_str(f'comp {ci} major = ')} + str(c.major()));");
        for fld in ["minor", "patch"] {
            label = f"comp {ci} {fld} = ";
            parts.append(f"    ov = c.{fld}();");
            parts.append("    if ov is None {");
            parts.append(f"        print({jac_str(label + 'None')});");
            parts.append("    } else {");
            parts.append(f"        print({jac_str(label)} + str(ov));");
            parts.append("    }");
        }
        parts.append(f"    if c.matches(v0) {{");
        parts.append(f"        print({jac_str(f'comp {ci} m0 = 1')});");
        parts.append("    } else {");
        parts.append(f"        print({jac_str(f'comp {ci} m0 = 0')});");
        parts.append("    }");
        parts.append("    c.close();");
    }
    probe.extend(parts);
    probe.append("}");
    return run_na_probe(
        SO, probe, "semver_conf.na.jac", "semver_conf", strip_blank=True
    );
}


test "na cpython semver handle-param conformance" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_side() == na_side();
}
