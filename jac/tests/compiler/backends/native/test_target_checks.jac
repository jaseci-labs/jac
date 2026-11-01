"""The native backend reads its target in a few named places only (#10219).

What a C library spells, lays out or numbers per target belongs to the
runtime floor, and object formats and library naming belong to the linker, so
lowering to MIR and emitting LLVM IR from it stay the same for every 64-bit
target. This gate keeps it that way: a new read of the target anywhere else in
the MIR backend fails here and has to move behind the floor or join the list
below with a reason.
"""
import re;
import from pathlib { Path }

"""Where the MIR backend may read its target, and why."""
glob ALLOWED: dict[str, str] = {
         "emit_mir_module": "stamps the module's triple",
         "MirNativePass._run_impl": "hands the build's triple to the emitter"
     },
     TARGET_READS: tuple[str, ...] = ("triple", "native_target", "target_facts");

test "the MIR backend reads the target only where the list says" {
    import jaclang;
    mir_dir = Path(jaclang.__file__).resolve().parent
        / "compiler"
        / "backends"
        / "native"
        / "mir";
    found: dict[str, list[str]] = {};
    for path in sorted(mir_dir.rglob("*.jac")) {
        current = "";
        for (lineno, line) in enumerate(path.read_text().splitlines(), 1) {
            head = re.match(r"\s*(?:impl|def|static def)\s+([\w.]+)", line);
            if head {
                current = head.group(1);
            }
            if any(word in line for word in TARGET_READS) {
                found.setdefault(current, []).append(f"{path.name}:{lineno}");
            }
        }
    }
    stray = {
        name: places
        for (name, places) in found.items()
        if name not in ALLOWED
    };
    assert not stray , (
        "these MIR backend declarations read the target; move the decision "
        f"behind the runtime floor or the linker: {stray}"
    );
}
