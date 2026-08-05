import from jaclang.compiler.type_system.compose_signatures {
    ComposeSig,
    ComposeParamKind,
    SigParam,
    parse_signature_text,
    slot_table
}

def _param_decl(p: SigParam) -> str {
    if p.kind == ComposeParamKind.MODIFIER {
        return f"{p.name}: (ModifierChain | None) = None";
    }
    if p.kind == ComposeParamKind.EVENT or p.kind == ComposeParamKind.SLOT {
        return f"{p.name}: (any | None) = None";
    }
    return f"{p.name}: any = None";
}

def emit_widget_stubs(sigs: list[ComposeSig]) -> str {
    lines: list[str] = [
        "# ── GENERATED WIDGETS — do not edit below this marker ──",
        "# Regenerate from AndroidX signature files via compose_stub_gen.",
        "# Relies on the core types (Composable, ModifierChain) declared above."
    ];
    for sig in sigs {
        if not sig.params {
            lines.append(f"def:pub {sig.name}() -> Composable;");
            continue;
        }
        decls = [_param_decl(p) for p in sig.params];
        body = ",\n    ".join(decls);
        lines.append(f"def:pub {sig.name}(\n    {body}\n) -> Composable;");
    }
    return "\n".join(lines) + "\n";
}

def generate(signature_text: str) -> str {
    return emit_widget_stubs(parse_signature_text(signature_text));
}
