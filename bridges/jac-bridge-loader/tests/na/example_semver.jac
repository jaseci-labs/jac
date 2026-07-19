# EXAMPLE-PASS metric (north star): the canonical semver "compare two versions"
# example must produce the EXACT expected output under BOTH runtimes.
#
# Unlike a *_conformance.jac vertical (which asserts only na == cpython, so a
# shared-wrong answer still passes), an example test pins a GOLDEN `EXPECTED`
# captured from the crate's docs.rs / README, then asserts
# EXPECTED == cpython_side() == na_side(). A green example = "a real user program
# on this crate runs on Jac and prints the right thing" -- pass/fail per crate.
#
# Canonical example (semver README, adapted): construct two versions, show their
# Display form, and compare them. The upstream README uses `Version::parse`, but
# `parse` is a `#[jac(assoc)]` static (na-gated: a static cannot cross on na), so
# the na-runnable canonical form constructs via the `new` ctor `Version(M, m, p)`
# -- the same observable result. docs.rs asserts `v("1.2.3") < v("1.2.4")`.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness { bridge_so, jac_str, llvm_shim, run_na_probe, skip_gate }


glob SO = bridge_so("semver"),
     SHIM = llvm_shim(),
     # Golden output captured from the canonical example's expected behavior.
     EXPECTED = [
         "v1 = 1.2.3",
         "v2 = 1.2.4",
         "v1 < v2 = 1",
         "v2 < v1 = 0",
         "v1 == v1 = 1"
     ];


def cpython_side -> list {
    semver = load_bridge(str(SO));
    v1 = semver.Version(1, 2, 3);
    v2 = semver.Version(1, 2, 4);
    lines = [
        f"v1 = {v1.to_string()}",
        f"v2 = {v2.to_string()}",
        f"v1 < v2 = {int(v1.cmp(v2) < 0)}",
        f"v2 < v1 = {int(v2.cmp(v1) < 0)}",
        f"v1 == v1 = {int(v1.cmp(v1) == 0)}"
    ];
    v1.close();
    v2.close();
    return lines;
}


def na_side -> list {
    probe = [
        "\nwith entry {",
        f"    v1 = Version(1, 2, 3);",
        f"    v2 = Version(1, 2, 4);",
        f"    print({jac_str('v1 = ')} + v1.to_string());",
        f"    print({jac_str('v2 = ')} + v2.to_string());",
        f"    if v1.cmp(v2) < 0 {{ print({jac_str('v1 < v2 = 1')}); }} " + f"else {{ print({jac_str(
            'v1 < v2 = 0'
        )}); }}",
        f"    if v2.cmp(v1) < 0 {{ print({jac_str('v2 < v1 = 1')}); }} " + f"else {{ print({jac_str(
            'v2 < v1 = 0'
        )}); }}",
        f"    if v1.cmp(v1) == 0 {{ print({jac_str('v1 == v1 = 1')}); }} " + f"else {{ print({jac_str(
            'v1 == v1 = 0'
        )}); }}",
        "    v1.close();",
        "    v2.close();",
        "}"
    ];
    return run_na_probe(
        SO, probe, "example_semver.na.jac", "example_semver", strip_blank=True
    );
}


test "example: semver compare two versions (golden, na == cpython)" {
    if skip_gate(SO, SHIM) {
        return;
    }
    # The north-star assertion: BOTH runtimes match the docs-captured golden.
    assert cpython_side() == EXPECTED;
    assert na_side() == EXPECTED;
}
