import os;
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.frontend.unitree { UniNode }

obj NativeNote {
    has site: UniNode,
        code: str,
        text: str,
        requires: bool = False;
}

def note_native(
    prog: JacProgram, site: UniNode, code: str, text: str, requires: bool = False
) -> None {
    path = site.loc.mod_path if site.loc is not None else "";
    if not path {
        return;
    }
    table = prog.analysis.native_notes;
    key = os.path.realpath(path);
    if key not in table {
        table[key] = {};
    }
    table[key][f"{id(site)}:{code}"] = NativeNote(
        site=site, code=code, text=text, requires=requires
    );
}

def native_notes_of(prog: JacProgram, mod_path: str) -> list[NativeNote] {
    found = prog.analysis.native_notes.get(os.path.realpath(mod_path));
    return list(found.values()) if found is not None else [];
}

def forget_native_notes(prog: JacProgram, mod_path: str) {
    prog.analysis.native_notes.pop(os.path.realpath(mod_path), None);
}
