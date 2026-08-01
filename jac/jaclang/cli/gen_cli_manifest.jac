import from jaclang.cli.command { Arg, ArgKind, CommandSpec, arg_typ_name }
import from jaclang.cli.manifest {
    ArgMeta,
    CommandMeta,
    TIER_SECTIONS,
    TOMBSTONED_VERBS,
    VERB_BUDGET
}

glob FEATURE_MODULES: list[str] = [
         "jaclang.byllm.cli",
         "jaclang.cli.shadcn.cli",
         "jaclang.runtimelib.client.cli",
         "jaclang.scale.plugin",

     ],
     MANIFEST_IMPL_REL: str = "cli/impl/manifest.impl.jac";

def _discover_core_modules -> list[str] {
    src_root = _resolve_jaclang_root();
    if src_root is None {
        raise RuntimeError(
            "could not locate jaclang source root; run `jac gen-cli-manifest`"
            " from a jaclang source checkout (or set JAC_DEV_SOURCE)."
        );
    }
    cmds_dir = src_root / "jaclang" / "cli" / "commands";
    excluded: set[str] = {"cli_helpers"};
    seen: set[str] = set();
    mods: list[str] = [];
    for entry in sorted(cmds_dir.iterdir()) {
        if entry.is_dir() or entry.suffix not in (".jac", ".py") {
            continue;
        }
        stem = entry.stem;
        if stem in excluded or stem.startswith("_") or stem in seen {
            continue;
        }
        seen.add(stem);
        mods.append(f"jaclang.cli.commands.{stem}");
    }
    return mods;
}

def collect -> list[CommandSpec] {
    import importlib;
    import from jaclang.cli.registry { get_registry }

    for mod in _discover_core_modules() + FEATURE_MODULES {
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
    raise TypeError(f"unsupported manifest literal type: {type(v).__name__}");
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

def _arg_fields(arg: Arg) -> list[str] {
    fields: list[str] = [f"name={_q(arg.name)}"];
    if arg.kind != ArgKind.OPTION {
        fields.append(f"kind=ArgKind.{arg.kind.name}");
    }
    typ_name = arg_typ_name(arg.typ);
    if typ_name != "str" {
        fields.append(f"typ={_q(typ_name)}");
    }
    if arg.default is not None {
        fields.append(f"default={_value_literal(arg.default)}");
    }
    if arg.help {
        fields.append(f"help={_q(arg.help)}");
    }
    if arg.short is not None {
        fields.append(f"short={_q(arg.short)}");
    }
    if arg.choices is not None {
        fields.append(f"choices={_choices_literal(arg.choices)}");
    }
    if arg.required {
        fields.append("required=True");
    }
    if arg.dest is not None {
        fields.append(f"dest={_q(arg.dest)}");
    }
    if arg.metavar is not None {
        fields.append(f"metavar={_q(arg.metavar)}");
    }
    if arg.config_key is not None {
        fields.append(f"config_key={_q(arg.config_key)}");
    }
    return fields;
}

def _arg_rows(args: list[Arg]) -> list[str] {
    rows: list[str] = [];
    for arg in args {
        fields = _arg_fields(arg);
        rows.append("                ArgMeta(");
        for (i, field) in enumerate(fields) {
            suffix = "," if i < len(fields) - 1 else "";
            rows.append(f"                    {field}{suffix}");
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
        if spec.description {
            rows.append(f"            description={_text_literal(spec.description)},");
        }
        if spec.examples {
            rows.append(f"            examples={_examples_literal(spec.examples)},");
        }
        if spec.args {
            rows.append("            args=[");
            for arg_row in _arg_rows(spec.args) {
                rows.append(arg_row);
            }
            rows.append("            ]");
        } else {
            rows.append("            args=[]");
        }
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

def _dataclass_field_names(typ: type) -> list[str] {
    import dataclasses;

    return [
        f.name
        for f in dataclasses.fields(typ)
        if f.init and not f.name.startswith("_")
    ];
}

def _command_meta_field_names -> list[str] {
    return _dataclass_field_names(CommandMeta);
}

def _arg_meta_field_names -> list[str] {
    return _dataclass_field_names(ArgMeta);
}

def _format_generated(content: str) -> str {
    import tempfile;
    import warnings;
    import from pathlib { Path }
    import jaclang.cli.commands.analysis;

    with tempfile.TemporaryDirectory() as fmt_dir {
        impl_path = Path(fmt_dir) / "manifest.impl.jac";
        impl_path.write_text(content, encoding="utf-8");
        try {
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
        } except Exception as exc {
            warnings.warn(
                "jac fmt failed during manifest generation; using unformatted "
                f"output: {exc}",
                stacklevel=2
            );
        }
        return impl_path.read_text(encoding="utf-8");
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

def _arg_field_value(arg: Arg, field: str) -> any {
    if field == "kind" {
        return arg.kind;
    }
    if field == "typ" {
        return arg_typ_name(arg.typ);
    }
    return getattr(arg, field);
}

def _arg_signature(arg: Arg) -> tuple {
    return tuple(_arg_field_value(arg, field) for field in _arg_meta_field_names());
}

def _meta_arg_signature(arg: ArgMeta) -> tuple {
    return tuple(getattr(arg, field) for field in _arg_meta_field_names());
}

def _spec_field_value(cmd: CommandSpec, field: str) -> any {
    if field == "handler_module" {
        h = cmd.handler;
        return h.__module__ if h is not None else "";
    }
    if field == "handler_name" {
        h = cmd.handler;
        return h.__name__ if h is not None else "";
    }
    if field == "args" {
        return [_arg_signature(a) for a in cmd.args];
    }
    if field == "examples" {
        return list(getattr(cmd, field));
    }
    return getattr(cmd, field);
}

def _spec_signature(cmd: CommandSpec) -> tuple {
    return tuple(
        _spec_field_value(cmd, field) for field in _command_meta_field_names()
    );
}

def _meta_signature(cmd: CommandMeta) -> tuple {
    return tuple(
        [_meta_arg_signature(a) for a in cmd.args]
            if field == "args"
            else getattr(cmd, field) for field in _command_meta_field_names()
    );
}

def verify_drift -> list[str] {
    specs = collect();
    errors = validate_specs(specs);
    current = _read_current();
    expected = _format_generated(generate());
    if current == expected {
        return errors;
    }

    fresh: dict[str, tuple] = {cmd.name: _spec_signature(cmd) for cmd in specs};
    committed: dict[str, tuple] = {};
    try {
        import from jaclang.cli.manifest { _command_routes }

        for cmd in _command_routes() {
            committed[cmd.name] = _meta_signature(cmd);
        }
    } except Exception {
        committed = {};
    }

    for name in sorted(set(committed) | set(fresh)) {
        if name not in committed {
            errors.append(f"{name}: in registry but missing from manifest");
        } elif name not in fresh {
            errors.append(f"{name}: in manifest but missing from registry");
        } elif committed[name] != fresh[name] {
            c = committed[name];
            f = fresh[name];
            field_names = _command_meta_field_names();
            differing = [
                field_names[i]
                for i in range(len(field_names))
                if c[i] != f[i]
            ];
            errors.append(
                f"{name}: manifest and registry disagree on fields: {differing}"
            );
        }
    }
    errors.append(
        "manifest.impl.jac route table is out of date with the command registry"
    );
    return errors;
}
