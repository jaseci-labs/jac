"""The repository's own archwire.jac files hold true facts in canonical form.

jaclang/archwire.jac is the one graph of jaclang's imports, natively lowered
subtrees included. The payload drops those subtrees, so it ships a copy of the
graph with every wire from them blanked in place: each surviving wire keeps the
line and column a checkout compiles it at, so a module woven in the payload and
in a checkout carries the same interface. Every archwire.jac in the tree is
already in the layout `jac fmt` renders.
"""

import os;
import shutil;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.wiring {
    ARCH_FILE_NAME,
    WiringSpec,
    parse_records,
    wiring_facts
}
import from jaclang.dist.payload.assemble { ship_wiring }
import from jaclang.dist.payload.fsutil { skip_jaclang }

glob _PKG: str = os.path.join(
         os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))),
         "jaclang"
     );


def _arch_files(top: str) -> list[str] {
    found: list[str] = [];
    for (dirpath, dirnames, filenames) in os.walk(top) {
        dirnames[:] = sorted(
            [
                d
                for d in dirnames
                if not d.startswith(".") and d not in ("node_modules", "__pycache__")
            ]
        );
        if ARCH_FILE_NAME in filenames {
            found.append(os.path.join(dirpath, ARCH_FILE_NAME));
        }
    }
    return found;
}


def _dropped(path: str) -> bool {
    return skip_jaclang(
        os.path.relpath(os.path.realpath(path), _PKG).replace(os.sep, "/")
    );
}


def _facts(source: str, path: str) -> tuple[WiringSpec, set[str]] {
    (failed, wires, rules) = parse_records(source, path);
    assert not failed , path;
    spec = WiringSpec(root_dir=_PKG, path=path, wires=wires, rules=rules);
    return (
        spec,
        {f"{consumer}|{binding.key()}" for (consumer, binding) in wiring_facts(wires)}
    );
}


test "the payload ships archwire.jac with the wires from modules it drops blanked in place" {
    source_path = os.path.join(_PKG, ARCH_FILE_NAME);
    with open(source_path) as f {
        source = f.read();
    }
    site = tempfile.mkdtemp(prefix="jac_ship_wiring_");
    try {
        ship_wiring(_PKG, site);
        with open(os.path.join(site, ARCH_FILE_NAME)) as f {
            shipped = f.read();
        }
        assert len(shipped) == len(source) , "the shipped copy must keep every offset";
        (spec, kept) = _facts(shipped, source_path);
        (full, everything) = _facts(source, source_path);
        placed = {(wire.provider, wire.line, wire.col) for wire in full.wires};
        stray: list[str] = [];
        moved: list[str] = [];
        for wire in spec.wires {
            found = spec.module_file(wire.provider);
            if found is not None and _dropped(found) {
                stray.append(wire.provider);
            }
            if (wire.provider, wire.line, wire.col) not in placed {
                moved.append(wire.provider);
            }
        }
        assert not stray , stray[:5];
        assert not moved , moved[:5];
        headers = [
            line.split()[2]
            for line in shipped.split("\n")
            if line.startswith("graph import ") and len(line.split()) == 4
        ];
        emptied = [
            scope
            for scope in headers
            if _dropped(os.path.join(_PKG, *scope.split(".")))
        ];
        assert not emptied , emptied[:5];
        assert kept < everything;
        assert not os.path.exists(
            os.path.join(site, "runtime", "python", ARCH_FILE_NAME)
        );
    } finally {
        shutil.rmtree(site, ignore_errors=True);
    }
}


test "every archwire.jac in the tree is in canonical layout" {
    tops = [_PKG, os.path.join(os.path.dirname(_PKG), "examples")];
    files = [
        path
        for top in tops
        if os.path.isdir(top) for path in _arch_files(top)
    ];
    assert files;
    drifted: list[str] = [];
    for path in files {
        with open(path) as f {
            text = f.read();
        }
        prog = JacProgram.jac_file_formatter(path);
        assert not prog.errors_had , (path, [str(e) for e in prog.errors_had[:3]]);
        if prog.mod.main.gen.jac != text {
            drifted.append(path);
        }
    }
    assert not drifted , drifted;
}
