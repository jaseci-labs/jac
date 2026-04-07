glob _analysis_cache: dict = {};
glob _CACHE_TTL: int = 60;


def _get_analysis(directory: str) -> dict {
    real_dir = os.path.realpath(directory);
    cached = _analysis_cache.get(real_dir);
    if cached {
        (ts, result) = cached;
        if time.time() - ts < _CACHE_TTL {
            return result;
        }
    }
    result = _analyze_project(directory);
    _analysis_cache[real_dir] = (time.time(), result);
    return result;
}


# ---------------------------------------------------------------------------
# AST extraction helpers
# ---------------------------------------------------------------------------
def _parse_file(file_path: str) -> dict | None {
    try {
        prog = JacProgram();
        module = prog.compile(file_path=file_path, type_check=False, no_cgen=True);
        if module is None {
            return None;
        }
        # Continue even with errors — partial AST is still useful
    } except Exception as e {
        sys.stderr.write(f"[jac_analyzer] Parse failed for {file_path}: {e}\n");
        return None;
    }

    archetypes: list = [];
    for arch in module.get_all_sub_nodes(uni.Archetype, brute_force=True) {
        arch_info = _extract_archetype(arch, file_path);
        if arch_info {
            archetypes.append(arch_info);
        }
    }

    imports: list = [];
    for imp in module.get_all_sub_nodes(uni.Import, brute_force=True) {
        imp_info = _extract_import(imp);
        if imp_info {
            imports.append(imp_info);
        }
    }

    return {"archetypes": archetypes, "imports": imports};
}


def _extract_archetype(arch: Any, file_path: str) -> dict | None {
    try {
        name = arch.name.sym_name if hasattr(arch.name, "sym_name") else str(arch.name);
        arch_type = arch.arch_type.name
            if hasattr(arch.arch_type, "name")
            else str(arch.arch_type);
        line = arch.loc.first_line if hasattr(arch, "loc") and arch.loc else 0;
    } except Exception {
        return None;
    }

    # Map token names to readable types
    type_map: dict = {
        "KW_NODE": "node",
        "KW_WALKER": "walker",
        "KW_EDGE": "edge",
        "KW_OBJECT": "obj"
    };
    kind = type_map.get(arch_type, arch_type);

    # Extract fields
    fields: list = [];
    try {
        for v in arch.get_has_vars() {
            vname = v.name.sym_name if hasattr(v.name, "sym_name") else str(v.name);
            vtype = _type_str(v);
            fields.append(f"{vname}:{vtype}");
        }
    } except Exception { }

    # Extract abilities
    abilities: list = [];
    entry_points: list = [];
    try {
        for m in arch.get_methods() {
            mname = m.name_ref.sym_name
                if hasattr(m.name_ref, "sym_name")
                else str(m.name_ref);
            is_llm = getattr(m, "is_genai_ability", False);
            suffix = " [by llm]" if is_llm else "";
            abilities.append(f"{mname}(){suffix}");

            # Walker entry points: can X with NodeType entry
            sig = getattr(m, "signature", None);
            if sig and hasattr(sig, "arch_tag_info") and sig.arch_tag_info {
                node_type = _expr_name(sig.arch_tag_info);
                event_name = sig.event.name
                    if hasattr(sig, "event") and hasattr(sig.event, "name")
                    else "";
                if node_type {
                    entry_points.append(
                        {"node_type": node_type, "event": event_name, "ability": mname}
                    );
                }
            }
        }
    } except Exception { }

    return {
        "name": name,
        "kind": kind,
        "file": file_path,
        "line": line,
        "fields": fields,
        "abilities": abilities,
        "entry_points": entry_points
    };
}


def _collect_type_params(ast_node: Any, out: list) -> None {
    type_name = type(ast_node).__name__;
    # Skip punctuation tokens (brackets, commas)
    if type_name == "Token" {
        name_str = str(getattr(ast_node, "name", ""));
        if "LSQUARE" in name_str or "RSQUARE" in name_str or "COMMA" in name_str {
            return;
        }
    }
    # Leaf type node — extract name
    if hasattr(ast_node, "sym_name")
    and type_name in ("BuiltinType", "Name", "NameAtom") {
        out.append(ast_node.sym_name);
        return;
    }
    # Recurse into children
    if hasattr(ast_node, "kid") and ast_node.kid {
        for child in ast_node.kid {
            _collect_type_params(child, out);
        }
    }
}


def _type_str(var: Any) -> str {
    try {
        tag = getattr(var, "type_tag", None);
        if tag is None {
            return "Any";
        }
        inner = tag.tag if hasattr(tag, "tag") else tag;
        return _expr_to_type_str(inner);
    } except Exception {
        return "Any";
    }
}


def _expr_to_type_str(expr: Any) -> str {
    try {
        # BuiltinType (str, int, bool, float, dict, list, etc.)
        if hasattr(expr, "sym_name") and hasattr(expr, "name") {
            return expr.sym_name;
        }
        # AtomTrailer: base[params] — e.g., dict[str, str], list[str]
        if type(expr).__name__ == "AtomTrailer" and hasattr(expr, "kid") {
            kids = expr.kid;
            if len(kids) >= 2 {
                base = _expr_to_type_str(kids[0]);
                # Collect all type-bearing nodes from remaining kids (skip punctuation tokens)
                type_params: list = [];
                for k in kids[1:] {
                    _collect_type_params(k, type_params);
                }
                if type_params {
                    return f"{base}[{', '.join(type_params)}]";
                }
                return base;
            }
        }
        # Name reference
        if hasattr(expr, "sym_name") {
            return expr.sym_name;
        }
        if hasattr(expr, "value") {
            return str(expr.value);
        }
        # Fallback
        s = str(expr);
        if len(s) < 40 {
            return s;
        }
        return "Any";
    } except Exception {
        return "Any";
    }
}


def _expr_name(expr: Any) -> str {
    try {
        if hasattr(expr, "sym_name") {
            return expr.sym_name;
        }
        if hasattr(expr, "value") and hasattr(expr.value, "sym_name") {
            return expr.value.sym_name;
        }
        if hasattr(expr, "target") and hasattr(expr.target, "sym_name") {
            return expr.target.sym_name;
        }
        # Fallback: try string representation, clean it up
        s = str(expr).strip();
        if s and len(s) < 50 {
            return s;
        }
        return "";
    } except Exception {
        return "";
    }
}


def _extract_import(imp: Any) -> dict | None {
    try {
        from_loc = "";
        if imp.from_loc and hasattr(imp.from_loc, "path") and imp.from_loc.path {
            parts: list = [];
            for p in imp.from_loc.path {
                if hasattr(p, "sym_name") {
                    parts.append(p.sym_name);
                } elif hasattr(p, "value") {
                    parts.append(str(p.value));
                } else {
                    parts.append(str(p));
                }
            }
            from_loc = ".".join(parts);
        }

        items: list = [];
        if imp.items {
            for item in imp.items {
                if hasattr(item, "name") {
                    iname = item.name.sym_name
                        if hasattr(item.name, "sym_name")
                        else str(item.name);
                    items.append(iname);
                } elif hasattr(item, "path") and item.path {
                    parts2: list = [];
                    for p in item.path {
                        parts2.append(p.sym_name if hasattr(p, "sym_name") else str(p));
                    }
                    items.append(".".join(parts2));
                }
            }
        }

        if not from_loc and not items {
            return None;
        }
        return {"from": from_loc, "items": items};
    } except Exception {
        return None;
    }
}


# ---------------------------------------------------------------------------
# Directory scanning
# ---------------------------------------------------------------------------
def _find_jac_files(directory: str) -> list {
    skip_dirs = {"__pycache__","node_modules",".git",".jac","__jac_gen__"};
    result: list = [];
    for (dirpath, dirnames, filenames) in os.walk(directory) {
        dirnames[:] = [
            d
            for d in dirnames
            if d not in skip_dirs and not d.startswith(".")
        ];
        for fname in sorted(filenames) {
            if fname.endswith(".jac") {
                result.append(os.path.join(dirpath, fname));
            }
        }
    }
    return result;
}


def _analyze_project(directory: str) -> dict {
    files = _find_jac_files(directory);
    all_archetypes: list = [];
    all_imports: dict = {};
    exports: dict = {};
    failed: list = [];

    for fpath in files {
        rel = os.path.relpath(fpath, directory);
        parsed = _parse_file(fpath);
        if parsed is None {
            failed.append(rel);
            continue;
        }

        # Collect archetypes
        for arch in parsed["archetypes"] {
            arch["rel_file"] = rel;
            all_archetypes.append(arch);
        }

        # Collect imports per file
        if parsed["imports"] {
            all_imports[rel] = parsed["imports"];
        }

        # Build export map (symbols defined per file)
        defined: list = [a["name"] for a in parsed["archetypes"]];
        if defined {
            exports[rel] = defined;
        }
    }

    return {
        "archetypes": all_archetypes,
        "imports": all_imports,
        "exports": exports,
        "failed": failed
    };
}


# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------
def _format_analysis(analysis: dict, directory: str) -> str {
    sections: list = [];
    archetypes = analysis["archetypes"];

    # Group by kind
    nodes = [
        a
        for a in archetypes
        if a["kind"] == "node"
    ];
    walkers = [
        a
        for a in archetypes
        if a["kind"] == "walker"
    ];
    edges = [
        a
        for a in archetypes
        if a["kind"] == "edge"
    ];
    objects = [
        a
        for a in archetypes
        if a["kind"] == "obj"
    ];

    # Client components: check if file is .cl.jac
    client_comps = [
        a
        for a in archetypes
        if a["rel_file"].endswith(".cl.jac")
    ];
    server_nodes = [
        a
        for a in nodes
        if not a["rel_file"].endswith(".cl.jac")
    ];

    # Nodes section
    if server_nodes {
        lines: list = ["Nodes:"];
        for n in server_nodes {
            fields_str = ", ".join(n["fields"][:8]) if n["fields"] else "no fields";
            abilities_str = "";
            if n["abilities"] {
                abilities_str = " | abilities: " + ", ".join(n["abilities"][:5]);
            }
            lines.append(
                f"  - {n['name']} ({n['rel_file']}:{n['line']}) — {fields_str}{abilities_str}"
            );
        }
        sections.append("\n".join(lines));
    }

    # Walkers section
    if walkers {
        lines2: list = ["Walkers:"];
        for w in walkers {
            visits_str = "";
            if w["entry_points"] {
                visit_names = [ep["node_type"] for ep in w["entry_points"]];
                visits_str = " — visits: " + " → ".join(visit_names);
            }
            lines2.append(f"  - {w['name']} ({w['rel_file']}:{w['line']}){visits_str}");
        }
        sections.append("\n".join(lines2));
    }

    # Edges section
    if edges {
        lines3: list = ["Edges:"];
        for e in edges {
            fields_str3 = ", ".join(e["fields"][:5]) if e["fields"] else "no fields";
            lines3.append(
                f"  - {e['name']} ({e['rel_file']}:{e['line']}) — {fields_str3}"
            );
        }
        sections.append("\n".join(lines3));
    }

    # Client components section
    if client_comps {
        lines4: list = ["Client Components (.cl.jac):"];
        for c in client_comps {
            state_str = ", ".join(c["fields"][:5]) if c["fields"] else "no state";
            lines4.append(
                f"  - {c['name']} ({c['rel_file']}:{c['line']}) — state: {state_str}"
            );
        }
        sections.append("\n".join(lines4));
    }

    # Objects section (only if not too many)
    if objects and len(objects) <= 10 {
        lines5: list = ["Objects:"];
        for o in objects {
            fields_str5 = ", ".join(o["fields"][:6]) if o["fields"] else "no fields";
            lines5.append(
                f"  - {o['name']} ({o['rel_file']}:{o['line']}) — {fields_str5}"
            );
        }
        sections.append("\n".join(lines5));
    }

    # Import map
    all_imports = analysis["imports"];
    exports = analysis["exports"];
    if all_imports {
        lines6: list = ["Import Map:"];
        for (file, imps) in sorted(all_imports.items()) {
            imp_strs: list = [];
            for imp in imps {
                if imp["from"] and imp["items"] {
                    imp_strs.append(f"{', '.join(imp['items'])} from {imp['from']}");
                }
            }
            if imp_strs {
                lines6.append(f"  {file}: imports [{'; '.join(imp_strs[:5])}]");
            }
        }
        if exports {
            lines6.append("");
            for (file, syms) in sorted(exports.items()) {
                lines6.append(f"  {file}: exports [{', '.join(syms[:10])}]");
            }
        }
        sections.append("\n".join(lines6));
    }

    # Failed files
    if analysis["failed"] {
        sections.append(f"Parse errors: {', '.join(analysis['failed'][:5])}");
    }

    if not sections {
        return "No .jac files found in directory.";
    }

    return "\n\n".join(sections);
}


# ---------------------------------------------------------------------------
# Public tool implementations
# ---------------------------------------------------------------------------
impl analyze_project(directory: str) -> str {
    if not directory {
        return "Error: directory is required.";
    }
    if not os.path.isdir(directory) {
        return f"Error: directory not found: {directory}";
    }

    try {
        analysis = _get_analysis(directory);
        return _format_analysis(analysis, directory);
    } except Exception as e {
        sys.stderr.write(f"[jac_analyzer] Analysis failed: {e}\n");
        return f"Analysis failed: {e}";
    }
}


impl find_symbol(name: str, directory: str = "") -> str {
    if not name {
        return "Error: symbol name is required.";
    }
    if not directory or not os.path.isdir(directory) {
        return f"Error: valid directory is required (got: '{directory}').";
    }

    try {
        analysis = _get_analysis(directory);
    } except Exception as e {
        return f"Analysis failed: {e}";
    }

    # Search archetypes for the symbol
    matches: list = [];
    usages: list = [];

    for arch in analysis["archetypes"] {
        if arch["name"] == name {
            matches.append(arch);
        }
    }

    # Search imports for usages
    for (file, imps) in analysis["imports"].items() {
        for imp in imps {
            if name in imp.get("items", []) {
                usages.append(
                    {"file": file, "type": "import", "from": imp.get("from", "")}
                );
            }
        }
    }

    # Search walker entry points for node type usages
    for arch in analysis["archetypes"] {
        for ep in arch.get("entry_points", []) {
            if ep["node_type"] == name {
                usages.append(
                    {
                        "file": arch["rel_file"],
                        "type": f"walker entry ({arch['name']}.{ep['ability']})"
                    }
                );
            }
        }
    }

    if not matches and not usages {
        return f"Symbol '{name}' not found in the project.";
    }

    parts: list = [];

    # Definition info
    for m in matches {
        fields_str = ", ".join(m["fields"][:8]) if m["fields"] else "no fields";
        abilities_str = ", ".join(m["abilities"][:5]) if m["abilities"] else "none";
        parts.append(
            f"Defined: {m['rel_file']}:{m['line']} ({m['kind']})\n"
            f"  Fields: {fields_str}\n"
            f"  Abilities: {abilities_str}"
        );

        # Suggest import statement
        # Find which module-relative path defines this
        for (file, syms) in analysis["exports"].items() {
            if name in syms and file == m["rel_file"] {
                mod_path = file.replace("/", ".").replace(".jac", "").replace(".cl", "");
                parts.append(f"  Import: import from {mod_path} {'{' + name + '}'}");
                break;
            }
        }
    }

    # Usage info
    if usages {
        usage_lines: list = ["Used by:"];
        for u in usages {
            if u["type"] == "import" {
                usage_lines.append(f"  - {u['file']} (import from {u['from']})");
            } else {
                usage_lines.append(f"  - {u['file']} ({u['type']})");
            }
        }
        parts.append("\n".join(usage_lines));
    }

    return "\n".join(parts);
}
