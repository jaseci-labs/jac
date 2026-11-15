import os;

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
) -> None;

def capability_notes_of(
    prog: JacProgram, mod_path: str, target: str = ""
) -> list[CapabilityNote];

def forget_capability_notes(prog: JacProgram, mod_path: str);

def placement_neutral(nd: UniNode) -> bool;
