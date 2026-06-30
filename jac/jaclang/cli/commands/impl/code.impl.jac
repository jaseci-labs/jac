import json;
import os;
import sys;
import from jaclang.cli.console { console }
import from jaclang.compiler.code_intel { CodeIntelligence }
import from jaclang.project.config { find_project_root }

glob _SCHEMA_VERSION = 1,
     _ACTIONS: list[str] = ["symbol", "uses", "map", "walkers", "slice", "diag"];


def _emit(text: str) {
    sys.stdout.write(text + "\n");
}


def _emit_json(command: str, payload: dict) {
    body: dict = {"schema_version": _SCHEMA_VERSION, "command": command};
    body.update(payload);
    _emit(json.dumps(body, indent=2));
}


def _fail(command: str, message: str, text: bool) -> int {
    if text {
        console.error(message);
    } else {
        _emit_json(command, {"error": message});
    }
    return 1;
}


def _load_ci(type_check: bool, structural: bool = False) -> CodeIntelligence {
    found = find_project_root();
    proj_dir = str(found[0]) if found is not None else os.getcwd();
    ci = CodeIntelligence(
        proj_dir=proj_dir, type_check=type_check, structural=structural
    );
    ci.load();
    return ci;
}


def _code_symbol(ci: CodeIntelligence, name: str, text: bool) -> int {
    defs = ci.lookup(name);
    uses = [
        r
        for r in ci.references(name)
        if r.role == "use"
    ];
    if not defs {
        if text {
            console.warning(
                f"No Jac symbol named '{name}' is defined in this project."
            );
        } else {
            _emit_json("symbol", {"query": name, "definitions": [], "uses": []});
        }
        return 2;
    }
    if text {
        lines: list[str] = [info.render() for info in defs];
        if uses {
            lines.append(f"\nused in {len(uses)} place(s):");
            for r in uses[:25] {
                lines.append("  " + r.render());
            }
        }
        _emit("\n".join(lines));
        return 0;
    }
    _emit_json(
        "symbol",
        {
            "query": name,
            "definitions": [info.to_dict() for info in defs],
            "uses": [r.to_dict() for r in uses]
        }
    );
    return 0;
}


def _code_uses(ci: CodeIntelligence, name: str, text: bool) -> int {
    refs = ci.references(name);
    if not refs {
        if text {
            console.warning(f"No definitions or uses of '{name}' were found.");
        } else {
            _emit_json("uses", {"query": name, "references": []});
        }
        return 2;
    }
    if text {
        _emit("\n".join([f"{r.role}  {r.render()}" for r in refs]));
        return 0;
    }
    _emit_json("uses", {"query": name, "references": [r.to_dict() for r in refs]});
    return 0;
}


def _code_map(ci: CodeIntelligence, kind: str, text: bool) -> int {
    archs = ci.archetypes(kind);
    if not archs and kind {
        if text {
            console.warning(f"No '{kind}' archetypes found in the project.");
        } else {
            _emit_json("map", {"kind": kind, "archetypes": []});
        }
        return 2;
    }
    if text {
        if not archs {
            console.warning(
                "No nodes, walkers, edges, or objects found in the project."
            );
            return 0;
        }
        rows = [f"{a.kind:7} {a.name}    [{a.file}:{a.line}]" for a in archs];
        _emit("\n".join(sorted(rows)));
        return 0;
    }
    _emit_json("map", {"kind": kind, "archetypes": [a.to_dict() for a in archs]});
    return 0;
}


def _code_walkers(ci: CodeIntelligence, node_type: str, text: bool) -> int {
    eps = ci.walkers_visiting(node_type);
    if not eps {
        if text {
            console.warning(f"No walkers traverse a '{node_type}' node.");
        } else {
            _emit_json("walkers", {"node_type": node_type, "entry_points": []});
        }
        return 2;
    }
    if text {
        _emit("\n".join([ep.render() for ep in eps]));
        return 0;
    }
    _emit_json(
        "walkers",
        {"node_type": node_type, "entry_points": [ep.to_dict() for ep in eps]}
    );
    return 0;
}


def _code_slice(ci: CodeIntelligence, name: str, depth: int, text: bool) -> int {
    sl = ci.slice_for(name, depth);
    if sl.target is None {
        if text {
            console.warning(f"No symbol named '{name}' was found.");
        } else {
            _emit_json("slice", {"query": name, "slice": sl.to_dict()});
        }
        return 2;
    }
    if text {
        _emit(sl.render());
        return 0;
    }
    _emit_json("slice", {"query": name, "slice": sl.to_dict()});
    return 0;
}


def _code_diag(ci: CodeIntelligence, file: str, text: bool) -> int {
    diags = ci.diagnostics(file);
    errors = len(
        [
            d
            for d in diags
            if d.severity == "error"
        ]
    );
    warnings = len(
        [
            d
            for d in diags
            if d.severity == "warning"
        ]
    );
    if text {
        if not diags {
            console.success("No errors or warnings.");
            return 0;
        }
        _emit("\n".join([d.render() for d in diags]));
        return 0;
    }
    _emit_json(
        "diag",
        {
            "file": file,
            "error_count": errors,
            "warning_count": warnings,
            "diagnostics": [d.to_dict() for d in diags]
        }
    );
    return 0;
}


def _print_usage {
    console.print();
    console.print("jac code -- ask the compiler about your code", style="bold");
    console.print(
        "  grep's structural successor: precise definitions, uses, types, and "
        "walkers.",
        style="muted"
    );
    console.print();
    console.print("  symbol <name>     definition(s) of a symbol + where it is used");
    console.print("  uses <name>       every read/write of a symbol (def/use-precise)");
    console.print("  map [kind]        structural overview (nodes/walkers/edges/objs)");
    console.print(
        "  walkers <type>    walkers whose entry points traverse a node type"
    );
    console.print("  slice <name>      typed neighbourhood of a symbol for prompts");
    console.print("  diag [path]       structured compiler errors and warnings");
    console.print();
    console.print(
        "  JSON by default; add --text for human-readable output.", style="muted"
    );
    console.print();
}


impl code(
    action: str = "", target: str = "", text: bool = False, depth: int = 1
) -> int {
    if not action {
        _print_usage();
        return 0;
    }
    if action not in _ACTIONS {
        return _fail(
            action,
            f"Unknown action '{action}'. Expected one of: " + ", ".join(_ACTIONS),
            text
        );
    }

    if action in ["symbol", "uses", "walkers", "slice"] and not target {
        return _fail(action, f"`jac code {action}` needs a name argument.", text);
    }

    structural = action in ["map", "walkers"];
    wants_types = not structural;
    try {
        ci = _load_ci(wants_types, structural);
    } except Exception as e {
        return _fail(action, f"Failed to load the project: {e}", text);
    }
    if action == "symbol" {
        return _code_symbol(ci, target, text);
    } elif action == "uses" {
        return _code_uses(ci, target, text);
    } elif action == "map" {
        return _code_map(ci, target, text);
    } elif action == "walkers" {
        return _code_walkers(ci, target, text);
    } elif action == "slice" {
        return _code_slice(ci, target, depth, text);
    }
    return _code_diag(ci, target, text);
}
