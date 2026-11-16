"""Every archwire.jac in the tree is already in the layout `jac fmt` renders."""

import os;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.wiring { ARCH_FILE_NAME }

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
