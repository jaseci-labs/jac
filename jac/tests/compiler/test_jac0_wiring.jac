"""jac0 weaves archwire.jac exactly as the full compiler does.

Seed modules are compiled by jac0, so their project imports come from the same
graph as everything else: jac0 reads the wires, places module-level imports
after the docstring and scoped imports at the top of their body, and agrees
with WiringSpec on every binding of every seed module.
"""

import os;
import shutil;
import tempfile;
import jaclang;
import from jaclang.jac0 { compile_jac, discover_impl_files, wired_imports }
import from jaclang.bootstrap_manifest { is_seed_source }
import from jaclang.compiler.driver.wiring { wiring_for_path }

glob _PKG: str = os.path.dirname(os.path.realpath(jaclang.__file__));


def _module_sources(top: str) -> list[str] {
    found: list[str] = [];
    for (dirpath, dirnames, filenames) in os.walk(top) {
        dirnames[:] = [
            d
            for d in dirnames
            if d != "impl" and not d.endswith(".impl") and not d.startswith(".")
        ];
        for name in filenames {
            if name.endswith(".jac") and name.count(".") == 1 {
                found.append(os.path.join(dirpath, name));
            }
        }
    }
    return found;
}


test "jac0 weaves module-level and scoped wires where the full compiler does" {
    base = tempfile.mkdtemp(prefix="jac0_wiring_");
    try {
        os.makedirs(os.path.join(base, "core"));
        with open(os.path.join(base, "jac.toml"), "w") as f {
            f.write("[project]\nname = \"seedwire\"\n");
        }
        with open(os.path.join(base, "archwire.jac"), "w") as f {
            f.write(
                "graph import core {\n"
                "    util ++> [\n"
                "        svc { now },\n"
                "        svc.Clock.read { later as soon },\n"
                "    ]\n"
                "    util --> svc.Clock.peek { later }\n"
                "}\n"
            );
        }
        with open(os.path.join(base, "core", "util.jac"), "w") as f {
            f.write("def now -> str {\n    return \"t\";\n}\n");
        }
        svc = os.path.join(base, "core", "svc.jac");
        source = (
            "\"\"\"The service.\"\"\"\n"
            "\n"
            "obj Clock {\n"
            "    def read -> str;\n"
            "}\n"
        );
        with open(svc, "w") as f {
            f.write(source);
        }
        impl_src = "impl Clock.read -> str {\n    return soon();\n}\n";
        python = compile_jac(
            source, svc, [(impl_src, svc.replace(".jac", ".impl.jac"))]
        );
        assert "from core.util import now" in python , python;
        assert python.index("The service.") < python.index("from core.util import now");
        read_at = python.index("def read");
        assert python.index("from core.util import later as soon") > read_at , python;
        assert "import later\n" not in python
            and "import later," not in python , python;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "jac0 and WiringSpec weave the same imports into every seed module" {
    mismatched: list[str] = [];
    checked = 0;
    for path in _module_sources(_PKG) {
        rel = os.path.relpath(path, _PKG).replace(os.sep, "/");
        if not is_seed_source(rel) {
            continue;
        }
        spec = wiring_for_path(path);
        assert spec is not None , path;
        consumer = spec.module_name(path);
        assert consumer is not None , path;
        expected: set[str] = set();
        for wire in spec.consumer_wires(consumer) {
            if not wire.is_injected {
                continue;
            }
            scope = ".".join(spec.consumer_scope(consumer, wire));
            for binding in wire.bindings() {
                expected.add(
                    f"{scope}|{spec.import_name(binding.provider)}|{binding.form}|"
                    f"{binding.name}|{binding.alias}"
                );
            }
        }
        woven: set[str] = set();
        for (scope, imports) in wired_imports(path).items() {
            for imp in imports {
                form = ("import type" if imp.is_typed else "import")
                    + (" from" if imp.is_from else "");
                if not imp.is_from {
                    woven.add(f"{'.'.join(scope)}|{imp.module}|{form}||{imp.alias}");
                    continue;
                }
                for named in imp.names {
                    parts = named.split(" as ");
                    alias = parts[1] if len(parts) > 1 else "";
                    woven.add(
                        f"{'.'.join(scope)}|{imp.module}|{form}|{parts[0]}|{alias}"
                    );
                }
            }
        }
        checked += 1;
        if woven != expected {
            mismatched.append(
                f"{rel}: jac0 only {sorted(woven - expected)[:3]}, "
                f"spec only {sorted(expected - woven)[:3]}"
            );
        }
    }
    assert checked > 50 , checked;
    assert not mismatched , mismatched[:5];
}
