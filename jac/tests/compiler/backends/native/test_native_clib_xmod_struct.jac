"""A foreign struct embeds a foreign struct declared in another module.

A module's own clib structs are laid out before any imported module's clib
block is processed, so a field typed by an imported foreign struct (a
`rusage`-shaped struct holding a `timeval` declared elsewhere) found no layout
and failed with E5092 "Native lowering failed for type 'timeval'". The
imported struct is now declared and laid out on first use, dependency first.

`clib_xmod_struct.jac` constructs the outer struct, reads and writes nested
fields, copies a nested struct out by value, lends a nested field to a
function of the declaring module and lends the whole struct to C, under every
memory profile and on the Python backend.
"""

import from tests.support { assert_native_identity }

import from pathlib { Path }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

test "a foreign struct nests an imported foreign struct by value" {
    out = assert_native_identity(str(FIXTURES / "clib_xmod_struct.jac"));
    assert out.split("\n")[:4]
        == ["read 3 4 5 77", "write 250 5000250", "copy 40 3", "cleared 0 0 0"] , out;
}
