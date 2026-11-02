"""A raise from a small checked helper lands in its caller's handler.

Every checked operation (an overflow, a shift, a null view) in a small
accessor raises; when the accessor is inlined into its callers for speed, a
raise from it must still land in the caller's handler, under every memory
profile.
"""

import os;
import tempfile;
import from pathlib { Path }
import from tests.support { native_build, native_run }

glob FIXTURE: str = "inline_checked_helpers.jac";

test "a raise from an inlined accessor lands in the caller's handler" {
    source = str(Path(__file__).resolve().parent / "fixtures" / FIXTURE);
    with tempfile.TemporaryDirectory() as scratch {
        for memory in ["rc", "managed"] {
            binary = os.path.join(scratch, f"inline_checked_helpers.{memory}");
            native_build(source, binary, memory=memory);
            out = native_run(binary);
            assert out.splitlines() == ["288 1071", "21 -1", "288 1071", "21 -1"] , (
                f"{memory}: {out}"
            );
        }
    }
}
