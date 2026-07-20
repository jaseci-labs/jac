import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.cli.manifest {
    ArgMeta,
    CommandMeta,
    TIER_SECTIONS,
    TOMBSTONED_VERBS,
    VERB_BUDGET
}

glob CORE_MODULES: list[str] = [
         "jaclang.cli.commands.execution",
         "jaclang.cli.commands.analysis",
         "jaclang.cli.commands.build",
         "jaclang.cli.commands.transform",
         "jaclang.cli.commands.project",
         "jaclang.cli.commands.guide",
         "jaclang.cli.commands.eject",
         "jaclang.cli.commands.tools",
         "jaclang.cli.commands.config",
         "jaclang.cli.commands.db",
         "jaclang.cli.commands.nacompile",
         "jaclang.cli.commands.ai",
         "jaclang.cli.commands.code",
         "jaclang.cli.commands.browse"
     ],
     FEATURE_MODULES: list[str] = [
         "jaclang.byllm.cli",
         "jaclang.cli.shadcn.cli",
         "jaclang.runtimelib.client.cli",
         "jaclang.scale.plugin",

     ],
     MANIFEST_IMPL_REL: str = "cli/impl/manifest.impl.jac";

def collect -> list[CommandSpec] {
    import importlib;
    import from jaclang.cli.registry { get_registry }

    for mod in CORE_MODULES + FEATURE_MODULES {
        importlib.import_module(mod);
    }

    reg = get_registry();
    return sorted(reg.get_all(include_hidden=True), key=lambda (s: any) { s.name; });
}

def validate_specs(specs: list[CommandSpec]) -> list[str] {
    errors: list[str] = [];
    names = [s.name for s in specs];
    if len(names) != len(set(names)) {
        errors.append("duplicate command names in manifest");
    }

    visible = [
        s.name
        for s in specs
        if not s.hidden
    ];
    if len(visible) > VERB_BUDGET {
        errors.append(
            f"{len(visible)} visible verbs exceed budget of {VERB_BUDGET}: {sorted(
                visible
            )}"
        );
    }

    revived = sorted(
        v
        for v in TOMBSTONED_VERBS
        if v in names
    );
    if revived {
        errors.append(f"tombstoned verb(s) present in manifest: {revived}");
    }

    for spec in specs {
        h = spec.handler;
        if h is None or not h.__module__ or not h.__name__ {
            errors.append(f"{spec.name}: missing handler reference");
        }
        if spec.tier and spec.tier not in TIER_SECTIONS {
            errors.append(f"{spec.name}: unknown tier {spec.tier!r}");
        }
    }
    return errors;
}

def _q(s: str) -> str {
    if "'" in s and '"' not in s {
        return f'"{s}"';
    }
    esc = s.replace("\\", "\\\\").replace("'", "\\'");
    return f"'{esc}'";
}

def _text_literal(s: str) -> str {
    if not s {
        return '""';
    }
    if "\n" in s or '"""' in s {
        esc = s.replace("\\", "\\\\").replace('"""', '\\"\\"\\"');
        return f'"""{esc}"""';
    }
    return _q(s);
}

def _value_literal(v: any) -> str {
    if v is None {
        return "None";
    }
    if isinstance(v, bool) {
        return "True" if v else "False";
    }
    if isinstance(v, int) {
        return str(v);
    }
    if isinstance(v, float) {
        return str(v);
    }
    if isinstance(v, str) {
        return _q(v);
    }
    if isinstance(v, list) {
        inner = ", ".join(_value_literal(x) for x in v);
        return f"[{inner}]";
    }
    if isinstance(v, tuple) {
        inner = ", ".join(_value_literal(x) for x in v);
        return f"({inner})";
    }
    return "None";
}

def _needs_literal(needs: list[str]) -> str {
    if not needs {
        return "[]";
    }
    inner = ", ".join(_q(n) for n in needs);
    return f"[{inner}]";
}

def _examples_literal(examples: list[tuple[str, str]]) -> str {
    if not examples {
        return "[]";
    }
    parts: list[str] = [];
    for (cmd, desc) in examples {
        parts.append(f"({_q(cmd)}, {_q(desc)})");
    }
    return "[" + ", ".join(parts) + "]";
}

def _choices_literal(choices: list[any] | None) -> str {
    if choices is None {
        return "None";
    }
    inner = ", ".join(_value_literal(c) for c in choices);
    return f"[{inner}]";
}

def _typ_name(typ: any) -> str {
    if typ is str {
        return "str";
    }
    if typ is int {
        return "int";
    }
    if typ is bool {
        return "bool";
    }
    if typ is float {
        return "float";
    }
    name = typ?.__name__;
    if isinstance(name, str) and name {
        return name;
    }
    return "str";
}

def _arg_rows(args: list[Arg]) -> list[str] {
    rows: list[str] = [];
    for arg in args {
        rows.append("                ArgMeta(");
        rows.append(f"                    name={_q(arg.name)},");
        rows.append(f"                    kind={_q(arg.kind.name)},");
        rows.append(f"                    typ={_q(_typ_name(arg.typ))},");
        rows.append(f"                    default={_value_literal(arg.default)},");
        rows.append(f"                    help={_q(arg.help)},");
        if arg.short is None {
            rows.append("                    short=None,");
        } else {
            rows.append(f"                    short={_q(arg.short)},");
        }
        rows.append(f"                    choices={_choices_literal(arg.choices)},");
        rows.append(f"                    required={arg.required},");
        if arg.dest is None {
            rows.append("                    dest=None,");
        } else {
            rows.append(f"                    dest={_q(arg.dest)},");
        }
        if arg.metavar is None {
            rows.append("                    metavar=None,");
        } else {
            rows.append(f"                    metavar={_q(arg.metavar)},");
        }
        if arg.config_key is None {
            rows.append("                    config_key=None");
        } else {
            rows.append(f"                    config_key={_q(arg.config_key)}");
        }
        rows.append("                ),");
    }
    return rows;
}

def _route_rows -> list[str] {
    specs = collect();
    drift = validate_specs(specs);
    if drift {
        raise RuntimeError("manifest validation failed:\n  - " + "\n  - ".join(drift));
    }
    rows: list[str] = [];
    for spec in specs {
        h = spec.handler;
        handler_module = h.__module__ if h is not None else "";
        handler_name = h.__name__ if h is not None else "";
        rows.append("        CommandMeta(");
        rows.append(f"            name={_q(spec.name)},");
        rows.append(f"            help={_q(spec.help)},");
        rows.append(f"            group={_q(spec.group)},");
        rows.append(f"            tier={_q(spec.tier)},");
        rows.append(f"            hidden={spec.hidden},");
        rows.append(f"            handler_module={_q(handler_module)},");
        rows.append(f"            handler_name={_q(handler_name)},");
        rows.append(f"            needs={_needs_literal(spec.needs)},");
        rows.append(f"            description={_text_literal(spec.description)},");
        rows.append(f"            examples={_examples_literal(spec.examples)},");
        rows.append("            args=[");
        for arg_row in _arg_rows(spec.args) {
            rows.append(arg_row);
        }
        rows.append("            ]");
        rows.append("        ),");
    }
    return rows;
}

def generate_body -> str {
    lines: list[str] = ["    return ["];
    for row in _route_rows() {
        lines.append(row);
    }
    lines.append("    ];");
    return "\n".join(lines);
}

def _resolve_jaclang_root -> Path | None {
    import os;
    import tomllib;
    import from pathlib { Path }

    dev = os.environ.get("JAC_DEV_SOURCE");
    if dev {
        src_root = Path(dev);
        if (src_root / "jaclang").is_dir() {
            return src_root;
        }
    }

    here = Path(os.getcwd());
    for parent in [here, *here.parents] {
        toml = parent / "jac.toml";
        if not toml.is_file() {
            continue;
        }
        try {
            data = tomllib.loads(toml.read_text(encoding="utf-8"));
        } except Exception {
            continue;
        }
        section = data.get("dev");
        if isinstance(section, dict) {
            src = section.get("jaclang_source");
            if isinstance(src, str) and src {
                src_root = (parent / src).resolve();
                if (src_root / "jaclang").is_dir() {
                    return src_root;
                }
            }
        }
        if (parent / "jaclang").is_dir() {
            return parent;
        }
        if (parent / "jac" / "jaclang").is_dir() {
            return parent / "jac";
        }
    }
    return None;
}

def _manifest_impl_path -> str {
    import jaclang;
    import from pathlib { Path }

    src_root = _resolve_jaclang_root();
    if src_root is not None {
        tree_path = src_root / "jaclang" / MANIFEST_IMPL_REL;
        if tree_path.is_file() {
            return str(tree_path);
        }
    }

    file_path = jaclang.__file__;
    if file_path is None {
        raise RuntimeError("jaclang.__file__ is None; cannot locate package");
    }
    return str(Path(file_path).parent / MANIFEST_IMPL_REL);
}

def _read_current -> str {
    with open(_manifest_impl_path(), encoding="utf-8") as f {
        return f.read();
    }
}

def _handwritten_tail(src: str) -> str {
    marker = "glob _COMMANDS:";
    idx = src.find(marker);
    if idx < 0 {
        raise RuntimeError(
            f"Could not find hand-written manifest tail in {_manifest_impl_path()}."
        );
    }
    return src[idx:];
}

def generate -> str {
    body = generate_body();
    routes = "def _command_routes -> list[CommandMeta] {\n" + body + "\n}\n\n";
    return routes + _handwritten_tail(_read_current());
}

def _format_generated(content: str) -> str {
    import tempfile;
    import from pathlib { Path }
    import jaclang.cli.commands.analysis;

    try {
        with tempfile.TemporaryDirectory() as fmt_dir {
            impl_path = Path(fmt_dir) / "manifest.impl.jac";
            impl_path.write_text(content, encoding="utf-8");
            prev: str = "";
            for _ in range(4) {
                jaclang.cli.commands.analysis.format(
                    [str(impl_path)], False, True, False, False
                );
                current = impl_path.read_text(encoding="utf-8");
                if current == prev {
                    break;
                }
                prev = current;
            }
            return impl_path.read_text(encoding="utf-8");
        }
    } except Exception {
        return content;
    }
}

def write_routes -> str {
    out = _manifest_impl_path();
    content = _format_generated(generate());
    with open(out, "w", encoding="utf-8") as f {
        f.write(content);
    }
    return out;
}

def _arg_signature(arg: Arg) -> tuple {
    return (
        arg.name,
        arg.kind.name,
        _typ_name(arg.typ),
        arg.default,
        arg.help,
        arg.short,
        arg.choices,
        arg.required,
        arg.dest,
        arg.metavar,
        arg.config_key,

    );
}

def _meta_arg_signature(arg: ArgMeta) -> tuple {
    return (
        arg.name,
        arg.kind,
        arg.typ,
        arg.default,
        arg.help,
        arg.short,
        arg.choices,
        arg.required,
        arg.dest,
        arg.metavar,
        arg.config_key,

    );
}

def _spec_signature(cmd: CommandSpec) -> tuple {
    h = cmd.handler;
    handler_module = h.__module__ if h is not None else "";
    handler_name = h.__name__ if h is not None else "";
    return (
        cmd.name,
        cmd.help,
        cmd.group,
        cmd.tier,
        cmd.hidden,
        handler_module,
        handler_name,
        list(cmd.needs),
        cmd.description,
        list(cmd.examples),
        [_arg_signature(a) for a in cmd.args],

    );
}

def _meta_signature(cmd: CommandMeta) -> tuple {
    return (
        cmd.name,
        cmd.help,
        cmd.group,
        cmd.tier,
        cmd.hidden,
        cmd.handler_module,
        cmd.handler_name,
        list(cmd.needs),
        cmd.description,
        list(cmd.examples),
        [_meta_arg_signature(a) for a in cmd.args],

    );
}

def verify_drift -> list[str] {
    import from jaclang.cli.manifest { _command_routes }

    specs = collect();
    fresh: dict[str, tuple] = {cmd.name: _spec_signature(cmd) for cmd in specs};

    committed: dict[str, tuple] = {};
    try {
        for cmd in _command_routes() {
            committed[cmd.name] = _meta_signature(cmd);
        }
    } except Exception as e {
        return [f"manifest.impl.jac could not be loaded: {e}"];
    }

    errors = validate_specs(specs);
    for name in sorted(set(committed) | set(fresh)) {
        if name not in committed {
            errors.append(f"{name}: in registry but missing from manifest");
        } elif name not in fresh {
            errors.append(f"{name}: in manifest but missing from registry");
        } elif committed[name] != fresh[name] {
            errors.append(f"{name}: manifest and registry disagree on command fields");
        }
    }
    if errors {
        errors.append(
            "manifest.impl.jac route table is out of date with the command registry"
        );
    }
    return errors;
}
