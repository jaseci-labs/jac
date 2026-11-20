"""One native build keys each module once.

The link plan asks whether every unit's cached products are still fresh, and
each unit is asked about again for every unit that depends on it. Each answer
recomputed the unit's module key (its content, annexes, environment and
wiring) and hashed its native interface again, so a one-file rebuild of a
program of a few hundred units spent seconds re-deriving facts that cannot
change while the build runs. The walk now holds the same per-run memo an
application prepare holds, and an interface read from disk keeps the digest
it was verified against.
"""
import os;
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import jaclang.compiler.backends.native.link_plan as link_plan_mod;
import jaclang.compiler.driver.jir as jir_mod;
import from jaclang.compiler.backends.native.link_plan { LinkPlan, build_link_plan }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.native_iface { NativeIface }
import from jaclang.compiler.driver.program { JacProgram }

test "a link plan walk keys each module once" {
    with TemporaryDirectory() as directory {
        path = os.path.join(os.path.realpath(directory), "unit.jac");
        with open(path, "w") as handle {
            handle.write("def one -> int {\n    return 1;\n}\n");
        }
        computed: list[str] = [];
        real_compute = jir_mod._compute_module_key_uncached;
        def counting(source_path: str) -> str {
            computed.append(source_path);
            return real_compute(source_path);
        }
        keys: list[str] = [];
        def walk(
            prog: JacProgram,
            roots: list[str],
            options: (CompileOptions | None) = None,
            mode: str = "",
            native_unit: bool = False
        ) -> LinkPlan {
            for _ in range(5) {
                keys.append(jir_mod.module_cache_key(path));
            }
            return LinkPlan(
                prog=prog,
                options=options or CompileOptions(),
                roots=roots,
                units=[],
                mode=mode,
                triple=""
            );
        }
        prog = JacProgram();
        with patch.object(jir_mod, "_compute_module_key_uncached", counting), patch.object(
            link_plan_mod, "_build_link_plan", walk
        ) {
            build_link_plan(prog, [path], CompileOptions());
            build_link_plan(prog, [path], CompileOptions());
        }
        assert len(set(keys)) == 1 , keys;
        assert computed.count(path) == 2 , (
            f"each walk should key the module once, and the next walk afresh: {computed}"
        );
        assert jir_mod._PREPARE_MEMO.get() is None , "the walk left its memo active";
    }
}

test "an interface read from disk keeps the digest it was verified against" {
    iface = NativeIface(module="unit", prefix="u_");
    raw = iface.to_bytes();
    read = NativeIface.from_bytes(raw);
    assert read is not None;
    assert NativeIface.read_digest(raw) == read.digest() == iface.digest();
    prog = JacProgram();
    registry = prog.native_units();
    stamp = registry.stamp_for(CompileOptions());
    def refuse_digest(*args: any) -> str {
        raise AssertionError("a verified interface was hashed again");
    }
    with patch.object(NativeIface, "digest", refuse_digest) {
        held = registry._register(
            "/nonexistent/unit.jac",
            read,
            stamp,
            "disk",
            digest=NativeIface.read_digest(raw) or ""
        );
    }
    assert held.digest == iface.digest();
}
