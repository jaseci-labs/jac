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
# Construction uses only ctors that exist on BOTH runtimes: `Version(major, minor,
# patch)` (the `new` ctor — `parse` lost the ctor race and is an na-gated static)
# and `VersionReq(req)` (`parse`, the sole VersionReq ctor). Accessors, `cmp`
# (-1/0/1), and `matches` (bool) cover scalar returns beside the handle params.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness { bridge_so, jac_str, llvm_shim, run_na_probe, skip_gate }


glob SO = bridge_so("semver"),
     SHIM = llvm_shim(),
     # (major, minor, patch) triples constructed on both sides.
     VERSIONS = [(1, 2, 3), (1, 3, 0), (1, 0, 0), (2, 0, 0)],
     # (requirement, index-into-VERSIONS) — matches() against a handle arg.
     REQ_CASES = [(">=1.2.0", 0), (">=1.2.0", 2), ("^1", 3), ("^1", 1)];


def cpython_side -> list {
    semver = load_bridge(str(SO));
    lines = [];
    vers = [semver.Version(a, b, c) for (a, b, c) in VERSIONS];
    # Field accessors (public fields exposed via overlay inject).
    for (i, v) in enumerate(vers) {
        lines.append(f"fields {i} = {v.major()}.{v.minor()}.{v.patch()}");
    }
    # cmp — a HANDLE PARAM (`other: &Version`), yields -1 / 0 / 1.
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
