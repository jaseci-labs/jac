# EXAMPLE-PASS metric (north star): the canonical sha2 example.
#
# STATUS: BLOCKED (skips today). `sha2` lives in the binder corpus only as a
# rustdoc-JSON fixture (tests/fixtures/sha2-0.11.0.json); there is no standing
# `jac-bridge-sha2` crate, so no libjac_bridge_sha2.so is built and `skip_gate`
# short-circuits. The surface it targets (`new`/`update`/`finalize`, the byte
# lane) is already bridged per the coverage baseline, so build is the ONLY blocker.
#
# Canonical example (sha2 README): hash a byte string and read the digest.
# SHA-256("abc") = ba7816bf...20015ad (32 bytes). The golden pins the digest
# length and the first/last byte so it is stable without a hex helper in-probe.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness { bridge_so, jac_str, llvm_shim, run_na_probe, skip_gate }


glob SO = bridge_so("sha2"),
     SHIM = llvm_shim(),
     EXPECTED = ["digest len = 32", "first = 186", "last = 173"];


def cpython_side -> list {
    sha2 = load_bridge(str(SO));
    h = sha2.Sha256();
    h.update(b"abc");
    d = h.finalize();
    lines = [f"digest len = {len(d)}", f"first = {d[0]}", f"last = {d[len(d) - 1]}"];
    h.close();
    return lines;
}


def na_side -> list {
    probe = [
        "\nwith entry {",
        "    h = Sha256();",
        f"    h.update({jac_str('abc')}.encode());",
        "    d = h.finalize();",
        f"    print({jac_str('digest len = ')} + str(len(d)));",
        f"    print({jac_str('first = ')} + str(d[0]));",
        f"    print({jac_str('last = ')} + str(d[len(d) - 1]));",
        "    h.close();",
        "}"
    ];
    return run_na_probe(
        SO, probe, "example_sha2.na.jac", "example_sha2", strip_blank=True
    );
}


test "example: sha2 digest of a byte string (golden, na == cpython)" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_side() == EXPECTED;
    assert na_side() == EXPECTED;
}
