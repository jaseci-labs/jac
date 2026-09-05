"""The link plan over a five-module diamond (#8943).

`top` imports `left`, `right` and `extra`, which all import `base`. The plan
walks the native edges each unit's interface records, orders the units
dependencies first, and links their objects plus one synthesized glue
object. Touching a body rewrites one object and leaves every interface
alone; touching an interface moves the dependents' recorded digests, which
the agreement check catches until they are recompiled. Two links from one
cache are byte-identical, and the whole-program mode produces the same
executable behavior from the same cache.
"""

import hashlib;
import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    NATIVE_LINK_MODE_BITCODE,
    NATIVE_LINK_MODE_OBJECTS
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.backends.native.link_plan {
    ArtifactKind,
    LinkPlanError,
    build_link_plan,
    link_artifact
}
import from jaclang.compiler.frontend.codeinfo {
    native_entry_name,
    native_glob_init_name
}

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures" / "link_diamond"),
     UNITS: list[str] = ["base.jac", "left.jac", "right.jac", "extra.jac", "top.jac"];

def _opts(mode: str = "") -> CompileOptions {
    return CompileOptions(
        aot_mode=True,
        default_codespace='native',
        force_target_program=True,
        skip_native_engine=True,
        native_link_mode=(mode or None)
    );
}

"""A private copy of the diamond, so edits never touch the fixtures."""
def _diamond_copy -> str {
    tmp = tempfile.mkdtemp(prefix="jac-diamond-");
    for name in UNITS {
        shutil.copy(os.path.join(FIXTURES, name), os.path.join(tmp, name));
    }
    return tmp;
}

def _plan_for(root_dir: str, mode: str = "") -> tuple[JacProgram, any] {
    prog = JacProgram();
    opts = _opts(mode);
    top = os.path.join(root_dir, "top.jac");
    mod = prog.compile(file_path=top, options=opts);
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    assert mod.gen.native_iface is not None;
    return (prog, build_link_plan(prog, [top], opts, mode=mode));
}

def _can_link_host -> bool {
    return sys.platform.startswith("linux") or sys.platform == "darwin";
}

test "the plan holds every unit of the diamond, dependencies first" {
    root = _diamond_copy();
    (prog, plan) = _plan_for(root);
    names = [os.path.basename(u.path) for u in plan.units];
    assert sorted(names) == sorted(UNITS) , names;
    assert names[-1] == "top.jac" , "the root comes last";
    assert names.index("base.jac") < names.index("left.jac");
    assert names.index("base.jac") < names.index("right.jac");
    assert names.index("base.jac") < names.index("extra.jac");
    assert plan.root_unit().path == os.path.realpath(os.path.join(root, "top.jac"));
    inits = plan.init_symbols();
    assert inits[0] == native_glob_init_name(os.path.join(root, "base.jac"));
    assert inits[-1] == native_glob_init_name(os.path.join(root, "top.jac"));
    assert plan.root_unit().iface.entry == native_entry_name(os.path.join(root, "top.jac"));
    assert "diamond_abi_version" in plan.pub_exports();
}

test "a body edit rewrites one object and keeps every interface" {
    root = _diamond_copy();
    (prog, plan) = _plan_for(root);
    registry = prog.native_units();
    obj_before = registry.object_for(os.path.join(root, "left.jac"), _opts());
    base_obj_before = registry.object_for(os.path.join(root, "base.jac"), _opts());
    assert obj_before is not None and base_obj_before is not None;

    left = Path(root) / "left.jac";
    left.write_text(left.read_text().replace("scale(p.sum(), 2)", "scale(p.sum() + 0, 2)"));
    (prog2, plan2) = _plan_for(root);
    registry2 = prog2.native_units();
    assert registry2.object_for(str(left), _opts()) != obj_before , "left's object must be rebuilt";
    assert registry2.object_for(os.path.join(root, "base.jac"), _opts()) == base_obj_before , "base is untouched";
    for u in plan2.units {
        prev = plan.unit(u.path);
        assert prev is not None and prev.digest == u.digest , f"{u.path} interface moved on a body edit";
    }
}

test "an interface edit moves the dependents' recorded digests" {
    root = _diamond_copy();
    (prog, plan) = _plan_for(root);
    base = Path(root) / "base.jac";
    base_digest = plan.unit(str(base)).digest;
    base.write_text(base.read_text() + "\ndef newly_exported(v: int) -> int {\n    return v;\n}\n");
    (prog2, plan2) = _plan_for(root);
    assert plan2.unit(str(base)).digest != base_digest , "an export must move base's digest";
    for u in plan2.units {
        for (dep, recorded) in prog2.native_units().recorded_native_deps(u.path) {
            live = plan2.unit(dep);
            if live is not None {
                assert recorded == live.digest , f"{u.path} still records a stale digest for {dep}";
            }
        }
    }
}

test "the agreement check names both modules on a stale dependency" {
    root = _diamond_copy();
    (prog, plan) = _plan_for(root);
    registry = prog.native_units();
    top = os.path.realpath(os.path.join(root, "top.jac"));
    stale = dict(registry.recorded_deps.get(top) or {});
    assert stale , "top must have recorded its dependencies";
    victim = sorted(stale.keys())[0];
    stale[victim] = "0" * 64;
    registry.recorded_deps[top] = stale;
    raised = "";
    try {
        build_link_plan(prog, [top], _opts());
    } except LinkPlanError as e {
        raised = str(e);
    }
    assert "disagreement" in raised , raised;
    assert os.path.basename(victim) in raised and "top.jac" in raised , raised;
}

test "two links from one cache are byte-identical" {
    if not _can_link_host() {
        assert True;
    } else {
        root = _diamond_copy();
        (prog, plan) = _plan_for(root);
        out_a = os.path.join(root, "top_a");
        out_b = os.path.join(root, "top_b");
        ra = link_artifact(plan, out_a, ArtifactKind.EXECUTABLE);
        rb = link_artifact(plan, out_b, ArtifactKind.EXECUTABLE);
        assert ra.plan_digest == rb.plan_digest;
        assert ra.sha256 == rb.sha256 , "the link must be deterministic";
        assert ra.layout_digest == rb.layout_digest;
        sidecar = Path(out_a + ".layout.json").read_text();
        assert ra.plan_digest in sidecar;
        run = subprocess.run([out_a], capture_output=True, text=True);
        assert run.returncode == 0 , run.stderr;
        assert run.stdout.strip() == "34" , run.stdout;
    }
}

test "objects mode and bitcode mode agree on the program" {
    if not _can_link_host() {
        assert True;
    } else {
        root = _diamond_copy();
        (prog_o, plan_o) = _plan_for(root, NATIVE_LINK_MODE_OBJECTS);
        (prog_b, plan_b) = _plan_for(root, NATIVE_LINK_MODE_BITCODE);
        assert plan_o.mode == NATIVE_LINK_MODE_OBJECTS;
        assert plan_b.mode == NATIVE_LINK_MODE_BITCODE;
        out_o = os.path.join(root, "top_objects");
        out_b = os.path.join(root, "top_bitcode");
        link_artifact(plan_o, out_o, ArtifactKind.EXECUTABLE);
        link_artifact(plan_b, out_b, ArtifactKind.EXECUTABLE);
        for out in (out_o, out_b) {
            run = subprocess.run([out], capture_output=True, text=True);
            assert run.returncode == 0 , run.stderr;
            assert run.stdout.strip() == "34" , run.stdout;
        }
    }
}

test "a shared link exports only the C ABI" {
    if not _can_link_host() {
        assert True;
    } else {
        root = _diamond_copy();
        prog = JacProgram();
        opts = _opts();
        base = os.path.join(root, "base.jac");
        prog.compile(file_path=base, options=opts);
        plan = build_link_plan(prog, [base], opts);
        suffix = ".dylib" if sys.platform == "darwin" else ".so";
        out = os.path.join(root, "libbase" + suffix);
        result = link_artifact(plan, out, ArtifactKind.SHARED);
        import ctypes;
        lib = ctypes.CDLL(out);
        assert lib.diamond_abi_version() == 1;
        assert hasattr(lib, "__jac_shared_init");
        assert hasattr(lib, "jac_retain") and hasattr(lib, "jac_release");
        assert result.sha256 == hashlib.sha256(Path(out).read_bytes()).hexdigest();
    }
}
