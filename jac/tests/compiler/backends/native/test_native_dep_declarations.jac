"""A native unit types its unchanged dependencies' declarations, not their bodies.

A unit lowers against what its imports declare: archetypes, their fields and
the defaults it inlines when it builds one, enums, globals and signatures. A
one-file rebuild used to run the whole analysis, every function body included,
on each module the rebuilt unit's imports reach. It now types those
declarations only. A dependency whose function bodies the importer lowers
itself (a generic it instantiates) is still analysed whole, and a change to
what an importer lays out still rebuilds the importer.
"""
import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
import from jaclang.compiler.backends.native.link_plan {
    ArtifactKind,
    build_link_plan,
    link_artifact
}
import from unittest.mock { patch }
import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
import from jaclang.compiler.frontend.unitree { Assignment, HasVar, Name }

glob SOURCES: dict[str, str] = {
         "shapes.jac": (
             "glob SCALE: float = 2.0;\n\n"
             "enum Tint { RED = 1, GREEN = 2 }\n\n"
             "def halve(v: float) -> float;\n\n"
             "obj Vec {\n"
             "    has x: float = 0.0,\n"
             "        y: float = halve(SCALE),\n"
             "        tint: Tint = Tint.GREEN,\n"
             "        tags: list[str] = [];\n\n"
             "    def norm1 -> float;\n"
             "}\n"
         ),
         "shapes.impl.jac": (
             "impl halve(v: float) -> float {\n"
             "    half_of = v / 2.0;\n"
             "    return half_of;\n"
             "}\n\n"
             "impl Vec.norm1 -> float {\n"
             "    total = self.x + self.y;\n"
             "    return total;\n"
             "}\n"
         ),
         "pick.jac": (
             "def first_of[T](items: list[T]) -> T {\n"
             "    chosen = items[0];\n"
             "    return chosen;\n"
             "}\n"
         ),
         "user.jac": (
             "import from shapes { Vec, Tint, SCALE }\n"
             "import from pick { first_of }\n\n"
             "def:pub measure -> float {\n"
             "    v = Vec(x=1.5);\n"
             "    v.tags.append(\"a\");\n"
             "    if v.tint == Tint.GREEN {\n"
             "        return v.norm1() + SCALE + first_of([0.25, 9.0]);\n"
             "    }\n"
             "    return 0.0;\n"
             "}\n"
         ),
         "top.jac": "import from user { measure }\n\nwith entry {\n    print(measure());\n}\n"
     };

def _opts -> CompileOptions {
    return CompileOptions(
        aot_mode=True, default_codespace='native', skip_native_engine=True
    );
}

def _project -> str {
    root_dir = tempfile.mkdtemp(prefix="jac-dep-decls-");
    for (name, text) in SOURCES.items() {
        Path(root_dir, name).write_text(text);
    }
    return root_dir;
}

def _plan_for(root_dir: str) -> tuple[JacProgram, any] {
    prog = JacProgram();
    opts = _opts();
    prog.options = opts;
    return (prog, build_link_plan(prog, [os.path.join(root_dir, "top.jac")], opts));
}

def _can_link_host -> bool {
    return sys.platform.startswith("linux") or sys.platform == "darwin";
}

def _run(plan: any, root_dir: str) -> str {
    output = os.path.join(root_dir, "program");
    link_artifact(plan, output, ArtifactKind.EXECUTABLE);
    run = subprocess.run([output], capture_output=True, text=True);
    assert run.returncode == 0 , run.stderr;
    return run.stdout.strip();
}

def _touch(path: str) {
    with open(path, "a") as handle {
        handle.write("\n# a comment changes nothing\n");
    }
}

obj DepTyping {
    has decl_types: bool,
        whole: bool,
        typed: dict[str, bool];
}

def _value_of(module: any, name: str) -> any {
    for var in module.get_all_sub_nodes(HasVar) {
        if var.name.value == name {
            return var.value;
        }
    }
    for assign in module.get_all_sub_nodes(Assignment) {
        for target in assign.target {
            if isinstance(target, Name) and target.value == name {
                return assign.value;
            }
        }
    }
    return None;
}

"""Build from `root_dir`, recording for each dependency a lowered unit reads
whether it was typed on its declarations or analysed whole, and whether the
value given to each of `names` carries a type."""
def _plan_recording(
    root_dir: str, names: list[str]
) -> tuple[JacProgram, any, dict[str, DepTyping]] {
    seen: dict[str, DepTyping] = {};
    original = NaIRGenPass._ensure_dep_inference;
    def record(lowering: NaIRGenPass, dep_mod: any) {
        original(lowering, dep_mod);
        analysis = lowering.prog.analysis;
        typed: dict[str, bool] = {};
        for name in names {
            value = _value_of(dep_mod, name);
            if value is not None {
                typed[name] = value.type is not None;
            }
        }
        seen[os.path.realpath(dep_mod.loc.mod_path)] = DepTyping(
            decl_types=analysis.provides(dep_mod, AnalysisFact.DECL_TYPES),
            whole=analysis.provides(dep_mod, AnalysisFact.TYPE_OF),
            typed=typed
        );
    }
    with patch.object(NaIRGenPass, "_ensure_dep_inference", record) {
        (prog, plan) = _plan_for(root_dir);
    }
    return (prog, plan, seen);
}

test "a one-file rebuild types its imports' declarations and leaves their bodies alone" {
    root_dir = _project();
    user = os.path.realpath(os.path.join(root_dir, "user.jac"));
    shapes = os.path.realpath(os.path.join(root_dir, "shapes.jac"));
    (prog, plan) = _plan_for(root_dir);
    cold_bitcode = prog.native_units().bitcode_for(user, _opts());
    assert cold_bitcode is not None;
    if _can_link_host() {
        assert _run(plan, root_dir) == "4.75";
    }

    _touch(user);
    (warm, warm_plan, seen) = _plan_recording(root_dir, ["y", "half_of", "total"]);
    assert warm.native_units().compiled_paths == [user] , warm.native_units().compiled_paths;
    facts = seen.get(shapes);
    assert facts is not None , sorted(seen);
    assert facts.decl_types and not facts.whole , "shapes was analysed whole";
    assert facts.typed == {"y": True, "half_of": False, "total": False} , facts.typed;
    assert warm.native_units().bitcode_for(user, _opts()) == cold_bitcode , "the rebuilt unit lowered differently";
    if _can_link_host() {
        assert _run(warm_plan, root_dir) == "4.75";
    }
}

test "a dependency whose generic body the importer instantiates is analysed whole" {
    root_dir = _project();
    user = os.path.realpath(os.path.join(root_dir, "user.jac"));
    pick = os.path.realpath(os.path.join(root_dir, "pick.jac"));
    _plan_for(root_dir);
    _touch(user);
    (warm, _, seen) = _plan_recording(root_dir, ["chosen"]);
    assert warm.native_units().compiled_paths == [user] , warm.native_units().compiled_paths;
    facts = seen.get(pick);
    assert facts is not None , sorted(seen);
    assert facts.whole;
    assert facts.typed == {"chosen": True} , facts.typed;
}

test "a field added to an imported archetype rebuilds the unit that lays it out" {
    root_dir = _project();
    user = os.path.realpath(os.path.join(root_dir, "user.jac"));
    shapes = os.path.realpath(os.path.join(root_dir, "shapes.jac"));
    _plan_for(root_dir);
    text = Path(shapes).read_text();
    Path(shapes).write_text(
        text.replace(
            "        tags: list[str] = [];",
            "        w: float = 0.5,\n        tags: list[str] = [];"
        )
    );
    Path(user).write_text(
        Path(user).read_text().replace("v.norm1() + SCALE", "v.norm1() + v.w + SCALE")
    );
    _touch(user);
    (warm, warm_plan) = _plan_for(root_dir);
    lowered = warm.native_units().compiled_paths;
    assert shapes in lowered and user in lowered , lowered;
    if _can_link_host() {
        assert _run(warm_plan, root_dir) == "5.25";
    }
}

test "a signature change in an imported method rebuilds its caller" {
    root_dir = _project();
    user = os.path.realpath(os.path.join(root_dir, "user.jac"));
    shapes = os.path.realpath(os.path.join(root_dir, "shapes.jac"));
    impl_path = os.path.join(root_dir, "shapes.impl.jac");
    (prog, plan) = _plan_for(root_dir);
    Path(shapes).write_text(
        Path(shapes).read_text().replace(
            "    def norm1 -> float;", "    def norm1(k: float = 2.0) -> float;"
        )
    );
    Path(impl_path).write_text(
        Path(impl_path).read_text().replace(
            "impl Vec.norm1 -> float {\n    total = self.x + self.y;",
            "impl Vec.norm1(k: float = 2.0) -> float {\n    total = (self.x + self.y) * k;"
        )
    );
    (warm, warm_plan) = _plan_for(root_dir);
    lowered = warm.native_units().compiled_paths;
    assert shapes in lowered and user in lowered , lowered;
    if _can_link_host() {
        assert _run(warm_plan, root_dir) == "7.25";
    }
}
