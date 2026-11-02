"""The native backend reads its target in a few named places only (#10219).

What a C library spells, lays out or numbers per target belongs to the
runtime floor, and object formats and library naming belong to the linker, so
lowering stays the same for every 64-bit target. This gate keeps it that way:
a new read of the target anywhere else in the MIR backend fails here and has
to move behind the floor or join the list below with a reason.
"""
import re;
import from pathlib { Path }

"""Where the MIR backend may read its target, and why."""
glob ALLOWED: dict[str, str] = {
         "MirNativePass._run_impl": "hands the target triple and data layout to emission",
         "emit_mir_module": "stamps the module's triple and data layout"
     };

glob TARGET_READS = re.compile(
         r"triple|native_target|sys\.platform|\"wasm|\"windows|\"darwin|\"win32"
     );

test "the MIR backend reads the target only where the list says" {
    import jaclang;
    mir = Path(jaclang.__file__).resolve().parent
        / "compiler"
        / "backends"
        / "native"
        / "mir";
    found: dict[str, list[str]] = {};
    for path in sorted(mir.rglob("*.jac")) {
        if not path.name.endswith(".impl.jac") {
            continue;
        }
        current = "";
        for (lineno, line) in enumerate(path.read_text().splitlines(), 1) {
            head = re.match(r"impl ([\w.]+)", line);
            if head {
                current = head.group(1);
            }
            if TARGET_READS.search(line) {
                found.setdefault(current, []).append(f"{path.name}:{lineno}");
            }
        }
    }
    assert "emit_mir_module" in found , (
        f"emission no longer stamps the target; the scan lost its anchor: {found}"
    );
    stray = {
        name: places
        for (name, places) in found.items()
        if name not in ALLOWED
    };
    assert not stray , (
        "these MIR backend functions read the target; move the decision "
        f"behind the runtime floor or the linker: {stray}"
    );
}
