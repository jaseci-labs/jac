import os;
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.unitree { Module, UniNode }

glob TARGET_NATIVE: str = "native",
     TARGET_CLIENT: str = "client",
     TARGET_SERVER: str = "server",
     TARGET_HEADERLESS: str = "headerless";

obj CapabilityNote {
    has site: UniNode,
        target: str,
        code: str,
        text: str,
        requires: bool = False;
}

def note_capability(
    prog: JacProgram,
    site: UniNode,
    target: str,
    code: str,
    text: str,
    requires: bool = False
) -> None {
    path = site.loc.mod_path if site.loc is not None else "";
    if not path {
        return;
    }
    table = prog.analysis.capability_notes;
    key = os.path.realpath(path);
    if key not in table {
        table[key] = {};
    }
    table[key][f"{id(site)}:{target}:{code}:{text}"] = CapabilityNote(
        site=site, target=target, code=code, text=text, requires=requires
    );
}

def capability_notes_of(
    prog: JacProgram, mod_path: str, target: str = ""
) -> list[CapabilityNote] {
    found = prog.analysis.capability_notes.get(os.path.realpath(mod_path));
    if found is None {
        return [];
    }
    return [
        note
        for note in found.values()
        if not target or note.target == target
    ];
}

def forget_capability_notes(prog: JacProgram, mod_path: str) {
    prog.analysis.capability_notes.pop(os.path.realpath(mod_path), None);
}

def placement_neutral(nd: UniNode) -> bool {
    """Whether `nd` sits in a module whose placement has not been decided:
    the first analysis of a module with no declared codespace. What only one
    codespace has is then a fact to record for placement, not an error.""";
    if nd.in_native_context() or nd.in_client_context() {
        return False;
    }
    mod = nd if isinstance(nd, Module) else nd.find_parent_of_type(Module);
    return mod is not None and mod.gen.placement_mode == "";
}
