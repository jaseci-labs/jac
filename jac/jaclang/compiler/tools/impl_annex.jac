import os;

def impl_annex_for(source_path: str) -> str {
    base = os.path.splitext(os.path.basename(source_path))[0];
    sibling = os.path.join(os.path.dirname(source_path), base + ".impl.jac");
    if os.path.exists(sibling) {
        return sibling;
    }
    found = sorted(discover_annex_files(source_path, ".impl.jac"));
    return found[0] if found else sibling;
}

def merge_impl_moves(source_path: str, impl_text: str) -> tuple[str, str] {
    annex = impl_annex_for(source_path);
    existing = "";
    if os.path.exists(annex) {
        with open(annex, "r", encoding="utf-8") as f {
            existing = f.read();
        }
    }
    merged = (existing.rstrip() + "\n\n" if existing.strip() else "") + impl_text;
    prog = JacProgram.jac_str_formatter(merged, annex, auto_lint=True);
    formatted = prog.mod.main.gen.jac if prog.mod and prog.mod.main else "";
    if not formatted.strip()
        or any(
            e.code is not None and e.code.code == "E5051" for e in prog.errors_had
        ) {
        formatted = merged;
    }
    return (annex, formatted);
}

def write_impl_moves(source_path: str, impl_text: str) -> str {
    (annex, code) = merge_impl_moves(source_path, impl_text);
    with open(annex, "w", encoding="utf-8") as f {
        f.write(code);
    }
    return annex;
}
