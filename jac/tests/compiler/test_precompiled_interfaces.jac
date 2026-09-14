import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import hashlib;
import shutil;
import from jaclang.compiler.driver.jir { SEC_IFACE, SEC_DIAG, read_section_bytes }
import from jaclang.dist.precompile_bytecode { precompile_unit, write_manifest }

def _package(base_path: Path) -> Path {
    package = base_path / "library";
    package.mkdir(parents=True);
    (package / "__init__.jac").write_text("");
    (package / "jac.toml").write_text(
        '[project]\nname = "library"\n[placement]\ndefault = "server"\n'
    );
    return package;
}

test "precompiled interfaces are independent of the staging directory" {
    with TemporaryDirectory() as directory {
        artifacts: list[bytes] = [];
        for stage in ("first", "second-longer-path") {
            package = _package(Path(directory) / stage);
            nested = package / "nested";
            nested.mkdir();
            (nested / "__init__.jac").write_text("");
            (package / "model.jac").write_text("obj Box { has value: int; }\n");
            source = nested / "api.jac";
            source.write_text(
                "import from ..model { Box }\n"
                    + "def make() -> Box { return Box(42); }\n"
            );
            data = precompile_unit(str(source), str(package), collect=False);
            assert data is not None;
            assert read_section_bytes(data, SEC_IFACE) is not None;
            artifacts.append(data);
        }
        assert artifacts[0] == artifacts[1] , (
            "identical sources produced different sealed interfaces after relocation"
        );
    }
}

test "precompiled modules carry their type interface on cold and cached builds" {
    with TemporaryDirectory() as directory {
        package = _package(Path(directory));
        source = package / "api.jac";
        source.write_text("def answer() -> int { return 42; }\n");
        for _attempt in range(2) {
            data = precompile_unit(str(source), str(package), collect=False);
            assert data is not None , "precompilation produced no artifact";
            assert read_section_bytes(data, SEC_IFACE) is not None , (
                "precompilation discarded the dependency's type interface"
            );
            assert read_section_bytes(data, SEC_DIAG) is not None , (
                "precompilation discarded the interface's analysis diagnostics"
            );
        }
    }
}

test "an installed precompiled interface resolves paths without rebuilding its source" {
    import from jaclang.compiler.driver { image as sealed }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.types.types { FunctionType, ClassType }
    with TemporaryDirectory() as directory {
        base_path = Path(directory).resolve();
        package = _package(base_path / "build");
        source = package / "api.jac";
        (package / "model.jac").write_text("obj Box { has value: int; }\n");
        source.write_text(
            "import from .model { Box }\n" + "def make() -> Box { return Box(42); }\n"
        );
        pre = package / "_precompiled";
        out = pre / sealed.python_tag();
        out.mkdir(parents=True);
        modules: dict[str, dict[str, any]] = {};
        for name in ("model", "api") {
            data = precompile_unit(
                str(package / (name + ".jac")), str(package), collect=False
            );
            assert data is not None;
            (out / (name + ".jir")).write_bytes(data);
            modules[name + ".jac"] = {
                "module": "library." + name,
                "jir": name + ".jir",
                "package": False,
                "sha256": hashlib.sha256(data).hexdigest()
            };
        }
        write_manifest(pre, "library", sealed.python_tag(), modules);
        installed = base_path / "installed" / "library";
        installed.parent.mkdir();
        shutil.move(str(package), str(installed));
        image = sealed.register_image(installed / "_precompiled");
        assert image is not None;
        try {
            program = JacProgram();
            registry = program.iface_registry();
            path = str(installed / "api.jac");
            iface_entry = registry.ensure(path, compile_on_miss=False);
            assert iface_entry is not None , "the installed interface could not be validated";
            module = registry._materialize(iface_entry);
            assert module is not None and module.stub_only;
            assert module.loc.mod_path == path , (module.loc.mod_path, path);
            assert not program.analysis.pass_runs , "installation rebuilt the dependency";
            evaluator = program.get_type_evaluator();
            function = evaluator.get_type_of_symbol(module.lookup("make"));
            assert isinstance(function, FunctionType);
            assert module.lookup("make").decl.loc.mod_path == path;
            box = evaluator.get_type_of_symbol(module.lookup("Box"));
            assert isinstance(box, ClassType);
            identity = box.shared.canonical_key();
            assert identity is not None and identity[0] == str(installed / "model.jac");
            returned = function.return_type;
            assert isinstance(returned, ClassType);
            assert returned.shared.same_class(box.shared);
            program.compile(path, options=program.options.for_symbols(need_tree=True));
            reloaded = JacProgram().iface_registry();
            cached = reloaded.ensure(path, compile_on_miss=False);
            assert cached is not None , "local persistence lost the installed interface";
            assert reloaded._materialize(cached).loc.mod_path == path , (
                "persisting a reused interface lost its relocation metadata"
            );
            code = program.get_bytecode(path);
            assert code is not None and code.co_filename == path;
            import from jaclang.compiler.placement.placement { summary_store }
            assert summary_store(program)[path].mod_path == path;
        } finally {
            sealed._images.remove(image);
        }
    }
}

test "relocation changes path fields without rewriting diagnostic messages" {
    import json;
    import from jaclang.compiler.driver.jir { JirPaths }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.ifacecache { DIAG_SCHEMA }
    paths = JirPaths(roots=["/build/library"], base_dir="/installed/library");
    original = "/build/library/api.jac";
    raw = json.dumps(
        {
            "schema": DIAG_SCHEMA,
            "profiles": {
                "profile": {
                    "errors": [],
                    "warnings": [
                        {
                            "msg": original,
                            "span": [original, 1, 1, 0, 1],
                            "related": [["declared here", [original, 2, 2, 0, 1]]]
                        }
                    ]
                }
            }
        }
    ).encode();
    profiles = JacProgram().iface_registry()._profiles_of(raw, paths.resolve);
    assert profiles is not None;
    warning = profiles["profile"]["warnings"][0];
    assert warning["msg"] == original;
    assert warning["span"][0] == "/installed/library/api.jac";
    assert warning["related"][0][1][0] == "/installed/library/api.jac";
    assert paths.resolve("/build/library_extra/api.jac")
        == "/build/library_extra/api.jac";
    local = JirPaths.from_bytes(paths.to_bytes());
    assert local.resolve(original) == "/installed/library/api.jac";
    relocated = JirPaths.from_bytes(local.to_bytes(), "/second/library");
    assert relocated.resolve(original) == "/second/library/api.jac";
    assert relocated.resolve("/installed/library/api.jac") == "/second/library/api.jac";
    import os;
    if os.sep == "/" {
        # A POSIX filename may contain a literal backslash.
        assert paths.resolve("/build/library/file\\name.jac")
            == "/installed/library/file\\name.jac";
        windows = JirPaths(roots=["C:\\build\\library"], base_dir="/installed/library");
        assert windows.resolve("C:\\build\\library\\api.jac")
            == "/installed/library/api.jac";
    }
}

test "compiler dependency paths survive runtime extraction relocation" {
    import tempfile;
    import from pathlib { Path }
    import from unittest.mock { patch }
    import jaclang.compiler.driver.jir as jir;
    with tempfile.TemporaryDirectory() as directory {
        directory = str(Path(directory).resolve());
        first = Path(directory, "first", "jaclang");
        second = Path(directory, "second", "jaclang");
        for root_dir in (first, second) {
            root_dir.mkdir(parents=True);
            (root_dir / "builtins.pyi").write_text("value: int\n");
        }
        app_dir = str(Path(directory, "app"));
        paths = jir.JirPaths(base_dir=app_dir);
        with patch.object(jir, "_COMPILER_PACKAGE_DIR", str(first)) {
            encoded = paths.encode(str(first / "builtins.pyi"), app_dir);
            deps = jir.ct_deps_section([str(first / "builtins.pyi")], base=app_dir);
            assert str(first) not in encoded;
            assert str(first).encode() not in deps;
            neighbor = str(first) + "_other/builtins.pyi";
            assert paths.encode(neighbor, app_dir) == neighbor;
        }
        with patch.object(jir, "_COMPILER_PACKAGE_DIR", str(second)) {
            assert paths.resolve(encoded) == str(second / "builtins.pyi");
            assert paths.encode(str(second / "builtins.pyi"), app_dir) == encoded;
            assert jir.ct_dep_text_fresh(deps.decode(), app_dir);
            assert str(second)
                in jir.absolutize_ct_deps_section(deps, app_dir).decode();
            (second / "builtins.pyi").write_text("value: str\n");
            assert not jir.ct_dep_text_fresh(deps.decode(), app_dir);
        }
    }
}

test "fresh publishing initializes and preserves the type interface" {
    import os;
    import subprocess;
    import sys;
    import jaclang;
    script = """
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
sys.path.insert(0, sys.argv[1])
from jaclang.dist.precompile_bytecode import precompile_unit
from jaclang.compiler.driver.jir import SEC_IFACE, read_section_bytes
with TemporaryDirectory() as directory:
    package = Path(directory) / 'library'
    package.mkdir()
    (package / '__init__.jac').write_text('')
    (package / 'jac.toml').write_text('[project]\\nname = "library"\\n[placement]\\ndefault = "server"\\n')
    source = package / 'example.jac'
    source.write_text('def answer() -> int { return 42; }\\n')
    data = precompile_unit(str(source), str(package))
    assert data is not None
    assert read_section_bytes(data, SEC_IFACE) is not None
""";
    env = dict(os.environ);
    env["JAC_STUBCAT_BUILDING"] = "1";
    result = subprocess.run(
        [
            sys.executable,
            "-I",
            "-S",
            "-c",
            script,
            str(Path(jaclang.__file__).parent.parent)
        ],
        env=env,
        capture_output=True,
        text=True,
        timeout=600
    );
    assert result.returncode == 0 , result.stdout + result.stderr;
}

test "publishing resolves conditional stub classes before application analysis" {
    import os;
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.compiler { JacCompiler }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.types.stubcat.locate { jaclang_pkg_dir }
    import from jaclang.compiler.types.stubcat.writer { module_of }
    import jaclang.dist.precompile_bytecode as precompile;
    import jaclang.compiler.types.stubcat.state as hook;
    package = jaclang_pkg_dir();
    compiler = JacCompiler();
    internal = JacProgram();
    internal._compiler = compiler;
    source = os.path.join(package, "compiler", "driver", "compile_options.jac");
    stub = os.path.join(package, "vendor", "typeshed", "stdlib", "types.pyi");
    # A fresh publisher must prepare its stub authority before resolving xrefs.
    with patch.object(hook, "active", return_value=None) {
        with precompile.precompile_unit_context(
            source, package, collect=False, program=internal
        ) as program {
            shared = program.iface_registry().resolve_shared(
                stub, "NoneType", "NoneType"
            );
            assert shared is not None , "sealing could not resolve a version-guarded stub class";
            assert module_of(shared.symbol_table) is not None , (
                "sealing created an orphan class instead of a reusable interface reference"
            );
        }
    }
}

test "bytecode completes a fresh symbol analysis without repeating its passes" {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.program { JacProgram }
    with TemporaryDirectory() as directory {
        package = _package(Path(directory));
        source = str((package / "api.jac").resolve());
        Path(source).write_text("def answer() -> int { return 42; }\n");
        program = JacProgram();
        options = CompileOptions(default_codespace="server", entry_point=source);
        analyzed = program.compile(source, options=options.for_symbols());
        before = dict(program.analysis.pass_runs);
        code = program._get_compiler().get_bytecode(source, program);
        assert code is not None;
        assert program.find_module(source) is analyzed;
        assert program.analysis.pass_runs.get("ASTValidationPass", 0)
            == before.get("ASTValidationPass", 0);
        program.release_compile_closure();
    }
}

test "native lowering follows a symbol only analysis" {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.compilation_context { compilation_scope }
    import from jaclang.compiler.driver.pipeline_runner { ModuleCompilation }
    import from jaclang.compiler.driver.program { JacProgram }
    with TemporaryDirectory() as directory {
        package = _package(Path(directory));
        source = str((package / "api.jac").resolve());
        Path(source).write_text("def answer() -> int { return 42; }\n");
        program = JacProgram();
        options = CompileOptions(default_codespace="native", entry_point=source);
        analyzed = program.compile(source, options=options.for_symbols());
        assert not analyzed.codespace_inferred;
        program.options = options;
        task = ModuleCompilation(program._get_compiler(), program, source, options);
        with compilation_scope(program.context_key, options) {
            task.parse();
        }
        assert task.module is not analyzed;
        assert task.module.codespace_inferred;
        program.release_compile_closure();
    }
}

test "sealed paths normalize symlink aliases before encoding" {
    import from jaclang.compiler.driver.jir { JirPaths, PRECOMPILE_SENTINEL }
    with TemporaryDirectory() as directory {
        base = Path(directory).resolve();
        package = _package(base);
        source = package / "api.jac";
        source.write_text("");
        alias = base / "linked-library";
        alias.symlink_to(package, target_is_directory=True);
        paths = JirPaths(base_dir=str(alias));
        encoded = paths.encode(str(alias / "api.jac"), str(package));
        assert encoded == PRECOMPILE_SENTINEL + "/api.jac";
        assert encoded == paths.encode(str(source), str(package));
        assert Path(paths.resolve(encoded)).resolve() == source;
    }
}
