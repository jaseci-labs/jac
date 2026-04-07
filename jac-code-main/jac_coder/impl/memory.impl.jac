impl find_or_create_memory(project_dir: str) -> ProjectMemory | None {
    if not project_dir {
        return None;
    }
    real_dir = os.path.realpath(project_dir);
    matches = [root()-->][?:ProjectMemory][?project_dir==real_dir];
    if matches {
        return matches[0];
    }
    memory = ProjectMemory(project_dir=real_dir);
    root() ++> memory;
    return memory;
}


impl _init_memory(memory: ProjectMemory, project_dir: str) -> None {
    memory.scan_attempted = True;

    # Try AST-based analysis first (fast, accurate, no LLM cost)
    ast_success = _init_memory_ast(memory, project_dir);

    if not ast_success {
        # Fallback: LLM-based scan (slower, costs tokens, but works if AST fails)
        _init_memory_llm(memory, project_dir);
    }

    memory.last_updated = datetime.now().isoformat();
}


def _init_memory_ast(memory: ProjectMemory, project_dir: str) -> bool {
    jac_files = _find_jac_files(project_dir);
    if not jac_files {
        return False;
    }

    try {
        analysis = _analyze_project(project_dir);
    } except Exception as e {
        sys.stderr.write(f"[memory] AST analysis failed: {e}\n");
        return False;
    }

    archetypes = analysis.get("archetypes", []);
    if not archetypes {
        return False;
    }

    # Build node details
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
    client_comps = [
        a
        for a in archetypes
        if a.get("rel_file", "").endswith(".cl.jac")
    ];

    # Architecture summary
    arch_parts: list = [];
    if nodes {
        arch_parts.append(f"{len(nodes)} nodes");
    }
    if walkers {
        arch_parts.append(f"{len(walkers)} walkers");
    }
    if edges {
        arch_parts.append(f"{len(edges)} edges");
    }
    if client_comps {
        arch_parts.append(f"{len(client_comps)} client components");
    }
    memory.architecture = f"Jac project with {', '.join(arch_parts)}";

    # Node details (compact format for context injection)
    if nodes {
        node_lines: list = ["Nodes:"];
        for n in nodes[:15] {
            fields_str = ", ".join(n["fields"][:6]) if n["fields"] else "no fields";
            abilities_str = "";
            if n["abilities"] {
                abilities_str = " | " + ", ".join(n["abilities"][:4]);
            }
            node_lines.append(
                f"  {n['name']} ({n['rel_file']}:{n['line']}) — {fields_str}{abilities_str}"
            );
        }
        memory.node_details = "\n".join(node_lines);
    }

    # Walker details with entry points
    if walkers {
        walker_lines: list = ["Walkers:"];
        for w in walkers[:15] {
            visits = "";
            if w["entry_points"] {
                visit_names = [ep["node_type"] for ep in w["entry_points"]];
                visits = " — visits: " + " → ".join(visit_names);
            }
            walker_lines.append(f"  {w['name']} ({w['rel_file']}:{w['line']}){visits}");
        }
        memory.walker_details = "\n".join(walker_lines);
    }

    # Client components
    if client_comps {
        comp_lines: list = ["Client Components:"];
        for c in client_comps[:10] {
            state = ", ".join(c["fields"][:4]) if c["fields"] else "no state";
            comp_lines.append(f"  {c['name']} ({c['rel_file']}:{c['line']}) — {state}");
        }
        # Append to node_details
        if memory.node_details {
            memory.node_details += "\n\n" + "\n".join(comp_lines);
        } else {
            memory.node_details = "\n".join(comp_lines);
        }
    }

    # Edge details → graph topology
    if edges {
        edge_strs: list = [];
        for e in edges[:10] {
            fields_str_e = ", ".join(e["fields"][:3]) if e["fields"] else "";
            edge_strs.append(
                f"{e['name']}({fields_str_e})" if fields_str_e else e["name"]
            );
        }
        memory.graph_topology = ", ".join(edge_strs);
    }

    # Import map
    all_imports = analysis.get("imports", {});
    exports = analysis.get("exports", {});
    if exports {
        imp_lines: list = ["Import map:"];
        for (file, syms) in sorted(exports.items())[:15] {
            imp_lines.append(f"  {file}: exports [{', '.join(syms[:8])}]");
        }
        memory.import_map = "\n".join(imp_lines);
    }

    # File map (from exports — more accurate than LLM guesses)
    for (file, syms) in exports.items() {
        memory.file_map[file] = ", ".join(syms[:6]);
    }

    print(
        f"[memory] AST scan complete: {len(archetypes)} archetypes from {len(
            jac_files
        )} files"
    );
    return True;
}


def _init_memory_llm(memory: ProjectMemory, project_dir: str) -> None {
    jac_files: list = [];
    try {
        for (dirpath, dirnames, filenames) in os.walk(project_dir) {
            dirnames[:] = [
                d
                for d in dirnames
                if not d.startswith(".") and d not in ("node_modules", "__pycache__")
            ];
            for filename in filenames {
                if filename.endswith(".jac") or filename == "jac.toml" {
                    rel = os.path.relpath(os.path.join(dirpath, filename), project_dir);
                    jac_files.append(rel);
                }
            }
        }
    } except Exception { }

    if not jac_files {
        return;
    }

    file_tree = "\n".join(jac_files[:30]);
    key_parts: list = [];
    for fname in ["jac.toml", "main.jac"] {
        fpath = os.path.join(project_dir, fname);
        try {
            with open(fpath, "r", encoding="utf-8") as f {
                content = f.read()[:2000];
            }
            key_parts.append(f"=== {fname} ===\n{content}");
        } except Exception { }
    }
    key_files = "\n\n".join(key_parts) if key_parts else "No key files found";

    try {
        scan = memory.profile_project(file_tree=file_tree, key_files=key_files);
        memory.architecture = scan.architecture;
        memory.file_map = scan.file_map;
        memory.conventions = scan.conventions;
    } except Exception as e {
        sys.stderr.write(f"[memory] LLM scan failed: {e}\n");
    }
}


impl update_memory_from_session(
    memory: ProjectMemory, files_modified: list[str], session_summary: str
) -> None {
    if not files_modified and not session_summary {
        return;
    }
    try {
        learnings = memory.collect_learnings(
            files_modified=files_modified, session_summary=session_summary
        );
        for (path, desc) in learnings.new_files.items() {
            memory.file_map[path] = desc;
        }
        for conv in learnings.new_conventions {
            if conv not in memory.conventions {
                memory.conventions.append(conv);
            }
        }
        for decision in learnings.new_decisions {
            if decision not in memory.past_decisions {
                memory.past_decisions.append(decision);
            }
        }
        for issue in learnings.known_issues {
            if issue not in memory.known_issues {
                memory.known_issues.append(issue);
            }
        }
        memory.last_updated = datetime.now().isoformat();
    } except Exception as e {
        sys.stderr.write(f"[memory] update failed: {e}\n");
    }
}
