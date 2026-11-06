"""Complex numbers lower natively as a pair of doubles.

MIR had no lowering for `complex` ("Native lowering failed for type
'complex'"), so the bundled cmath module demoted every function out of a
native closure. A complex value is now a by-value {re, im} pair: built by
`complex(...)`, read through `.real`/`.imag`, compared with `==`/`!=`, and
combined with +, -, * and / using CPython's mixed real/complex forms, Smith's
quotient and the C Annex G recovery of NaN results, as the NaIRGen backend did.
"""

import from pathlib { Path }
import from tests.support { assert_native_identity }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

test "complex values and cmath agree with the Python backend" {
    out = assert_native_identity(
        str(FIXTURES / "complex_values.jac"), profiles=["rc", "managed"]
    );
    lines = out.splitlines();
    assert "div -0.14 -0.48" in lines , out;
    assert "inf mul nan inf" in lines , out;
    assert "rdiv inf 0.0 -0.0" in lines , out;
    assert "zero div division by zero" in lines , out;
    assert "infj 0.0 inf" in lines , out;
}
