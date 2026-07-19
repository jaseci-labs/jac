# EXAMPLE-PASS metric (north star): the canonical uuid example.
#
# STATUS: BLOCKED (skips today). `uuid` lives in the binder corpus only as a
# rustdoc-JSON fixture (tests/fixtures/uuid-1.23.4.json); there is no standing
# `jac-bridge-uuid` crate in the workspace, so no libjac_bridge_uuid.so is built
# and `skip_gate` short-circuits. Add a `bridges/jac-bridge-uuid` cdylib
# (`#[jac_bridge] pub use uuid::*`) and this runs. The surface it targets
# (`from_slice` ctor + `hyphenated()`/`get_version_num()`) is already bridged per
# the coverage baseline, so build is the ONLY blocker.
#
# Canonical example (uuid docs, adapted to the na-crossable ctor): `new_v4()` is a
# static (na-gated) AND needs the `v4`/rng feature, so the deterministic canonical
# form builds from a fixed 16-byte slice via `from_slice` and shows the hyphenated
# text + version number.
import from jaclang.compiler.rust_bridge { load_bridge }
import from _harness { bridge_so, jac_str, llvm_shim, run_na_probe, skip_gate }


glob SO = bridge_so("uuid"),
     SHIM = llvm_shim(),
     # 16 bytes with the version nibble (byte 6 hi = 4) and variant (byte 8 hi = 8)
     # set so it renders as a well-formed v4 UUID.
     EXPECTED = ["uuid = 00112233-4455-4677-8899-aabbccddeeff", "version = 4"];


def cpython_side -> list {
    uuid = load_bridge(str(SO));
    b = bytes(
        [
            0x00,
            0x11,
            0x22,
            0x33,
            0x44,
            0x55,
            0x46,
            0x77,
            0x88,
            0x99,
            0xaa,
            0xbb,
            0xcc,
            0xdd,
            0xee,
            0xff
        ]
    );
    u = uuid.Uuid.from_slice(b);
    h = u.hyphenated();
    lines = [f"uuid = {h.to_string()}", f"version = {u.get_version_num()}"];
    h.close();
    u.close();
    return lines;
}


def na_side -> list {
    probe = [
        "\nwith entry {",
        "    b = bytes([0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x46, 0x77, " + "0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);",
        "    u = Uuid.from_slice(b);",
        "    h = u.hyphenated();",
        f"    print({jac_str('uuid = ')} + h.to_string());",
        f"    print({jac_str('version = ')} + str(u.get_version_num()));",
        "    h.close();",
        "    u.close();",
        "}"
    ];
    return run_na_probe(
        SO, probe, "example_uuid.na.jac", "example_uuid", strip_blank=True
    );
}


test "example: uuid from_slice hyphenated (golden, na == cpython)" {
    if skip_gate(SO, SHIM) {
        return;
    }
    assert cpython_side() == EXPECTED;
    assert na_side() == EXPECTED;
}
