import from jaclang.compiler.passes.ecmascript.intent.model { IntentComponent }
import from jaclang.compiler.passes.compose.compose_leaves {
    intent_expr_to_src,
    intent_stmts_to_src
}
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    IntentLeaf,
    StateField,
    RefField,
    Effect
}

impl ReactiveComposeEmitter._expr_src(expr: (IntentLeaf | None)) -> str {
    es_expr: any = expr;
    return intent_expr_to_src(es_expr);
}

impl ReactiveComposeEmitter._stmts_src(
    stmts: list[IntentLeaf], indent: str = "        "
) -> str {
    es_stmts: any = stmts;
    return intent_stmts_to_src(es_stmts, indent=indent);
}

def _emit_state_field(field: StateField) -> str {
    emitter = ReactiveComposeEmitter();
    init = emitter._expr_src(field.init_expr);
    return (f"    var {field.name} by remember {{ mutableStateOf({init}) }}");
}

def _emit_ref_field(field: RefField) -> str {
    emitter = ReactiveComposeEmitter();
    init = emitter._expr_src(field.init_expr);
    return f"    val {field.name} = remember {{ {init} }}";
}

def _emit_effect(effect: Effect) -> str {
    emitter = ReactiveComposeEmitter();
    if effect.is_entry or not effect.deps {
        deps = "Unit";
    } else {
        parts: list[str] = [];
        for dep in effect.deps {
            parts.append(emitter._expr_src(dep));
        }
        deps = ", ".join(parts) if parts else "Unit";
    }
    body = emitter._stmts_src(effect.body);
    if effect.is_async {
        return (
            "    val scope = rememberCoroutineScope()\n"
            f"    LaunchedEffect({deps}) {{\n"
            "        scope.launch {\n"
            f"{body}\n"
            "        }\n"
            "    }"
        );
    }
    return f"    LaunchedEffect({deps}) {{\n{body}\n    }}";
}

def _emit_async_boundary(a: any) -> str {
    emitter = ReactiveComposeEmitter();
    try_src = emitter._expr_src(a.try_expr);
    except_lines: list[str] = [];
    for ex in a.except_exprs {
        except_lines.append(f"            {emitter._expr_src(ex)}");
    }
    except_body = (
        "\n".join(except_lines) if except_lines else "            /* catch */"
    );
    return (
        "    val scope = rememberCoroutineScope()\n"
        "    LaunchedEffect(Unit) {\n"
        "        scope.launch {\n"
        "            try {\n"
        f"                {try_src}\n"
        "            } catch (e: Exception) {\n"
        f"{except_body}\n"
        "            }\n"
        "        }\n"
    );
}

impl ReactiveComposeEmitter.emit_prelude(comp: IntentComponent) -> str {
    lines: list[str] = [];
    for s in comp.state {
        lines.append(_emit_state_field(s));
    }
    for r in comp.refs {
        lines.append(_emit_ref_field(r));
    }
    for e in comp.effects {
        lines.append(_emit_effect(e));
    }
    for a in comp.asyncs {
        lines.append(_emit_async_boundary(a));
    }
    if not lines {
        return "";
    }
    return "\n".join(lines) + "\n";
}
