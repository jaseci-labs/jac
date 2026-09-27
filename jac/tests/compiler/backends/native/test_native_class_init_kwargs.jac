"""Construction binds keyword arguments against the initializer's own parameters.

An initializer may spell its receiver out (`def init(self: Point, x: int)`),
and the parameter list it declares then starts with that `self`. Native
construction already supplies the receiver as argument zero, so the binder
must count the parameters after it -- counting the `self` shifted every
keyword one slot, leaving `Point(x=1, y=2)` as `x=0, y=1`, and a positional
call passed one argument more than the initializer takes. The compiler's own
`JacProgram` is exactly this shape.

When a class (or an ancestor) has an initializer, its arguments belong to that
initializer alone: they are evaluated once and are not also stored into
same-named fields, so a field the initializer leaves alone keeps its default.
An inherited initializer binds keywords against the ancestor's signature.

A `class` archetype that has no initializer anywhere in its hierarchy keeps
Python class semantics: its `has` fields do not become constructor parameters
and it takes no arguments, which native construction refuses naming the class.
A `class` deriving an `obj` inherits the `obj`'s generated constructor.
"""

import from tests.support { assert_native_identity, jac_command }

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures"),
     PROFILES: list[str] = ["managed", "rc"];

test "keyword construction binds against the initializer like CPython" {
    assert_native_identity(
        os.path.join(FIXTURES, "class_init_kwargs.jac"), profiles=PROFILES
    );
}

test "a class with no initializer refuses constructor arguments" {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command(
            "build",
            "--native",
            os.path.join(FIXTURES, "class_no_init_args.jac"),
            "-o",
            out_bin
        ),
        capture_output=True,
        text=True,
        timeout=900
    );
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode != 0 , f"lowered instead of refused: {combined[-600:]}";
    assert "'Plain' is a `class` archetype with no initializer" in combined , combined[-800:];
}
