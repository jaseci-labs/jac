import json;
import shutil;
import sys;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.cli.guide_store {
    Guide,
    list_guides,
    list_docs,
    get_guide,
    guide_group,
    grouped_guides,
    doc_corpora,
    corpus_blurb,
    grep_guides
}

def _emit(text: str) {
    sys.stdout.write(text + "\n");
}

def _export_guides(dest: str) -> int {
    guides = list_guides();
    if not guides {
        console.error("No guides are bundled with this Jac installation.");
        return 1;
    }
    out_dir = Path(dest).expanduser();
    for g in guides {
        skill_dir = out_dir / g.name;
        skill_dir.mkdir(parents=True, exist_ok=True);
        shutil.copyfile(g.path, skill_dir / "SKILL.md");
    }
    console.success(f"Exported {len(guides)} guides to {out_dir}");
    console.print(
        "These are Claude Code Agent Skills -- point your agent tool at this "
        "directory (e.g. copy into ~/.claude/skills/).",
        style="muted"
    );
    return 0;
}

def _print_entries(entries: list[Guide]) {
    for g in entries {
        console.print(f"  {g.name}", style="bold cyan");
        console.print(f"      {g.description}", style="muted");
    }
}

def _corpus_listing(ns: str, members: list[Guide], as_json: bool) -> int {
    if as_json {
        _emit(
            json.dumps(
                [{"name": g.name, "description": g.description} for g in members],
                indent=2
            )
        );
        return 0;
    }
    console.print();
    console.print(f"Bundled docs: {ns}/ -- {corpus_blurb(ns)}", style="bold");
    console.print();
    _print_entries(members);
    console.print();
    console.print("Read one with:  jac guide <name>", style="muted");
    console.print();
    return 0;
}

def _search_guides(query: str, as_json: bool) -> int {
    hits = grep_guides(query);
    if as_json {
        _emit(
            json.dumps(
                [{"guide": h.guide, "line": h.line_no, "text": h.text} for h in hits],
                indent=2
            )
        );
        return 0;
    }
    if not hits {
        console.warning(f"No matches for '{query}' in any bundled guide or doc.");
        console.print(
            "Line hits need every term on one line -- try fewer or more "
            "specific terms.",
            style="muted"
        );
        return 0;
    }
    for h in hits {
        if h.line_no == 0 {
            _emit(f"{h.guide}: {h.text}");
        } else {
            _emit(f"{h.guide}:{h.line_no}: {h.text}");
        }
    }
    console.print();
    tail = "Read a doc with:  jac guide <name>";
    if len(hits) >= 200 {
        tail = "Showing the first 200 matches -- refine the query. " + tail;
    }
    console.print(f"{len(hits)} matches. {tail}", style="muted");
    return 0;
}

def _index_payload -> list[dict] {
    payload = [
        {
            "name": g.name,
            "description": g.description,
            "group": guide_group(g.name),
            "kind": "skill"
        } for g in list_guides()
    ];
    payload += [
        {
            "name": g.name,
            "description": g.description,
            "group": g.name.split("/")[0],
            "kind": "doc"
        } for g in list_docs()
    ];
    return payload;
}

impl guide(
    topic: str = "", search: str = "", export: str = "", as_json: bool = False
) -> int {
    if export {
        return _export_guides(export);
    }

    if topic {
        for (ns, members) in doc_corpora() {
            if topic.strip("/") == ns {
                return _corpus_listing(ns, members, as_json);
            }
        }
        g = get_guide(topic);
        if g is None {
            if as_json {
                _emit(json.dumps({"error": f"Guide '{topic}' not found"}));
            } else {
                console.error(f"No guide or doc named '{topic}'.");
                console.print(
                    "Run 'jac guide' to list topics, or "
                    "'jac guide --search <keyword>' to search everything.",
                    style="muted"
                );
            }
            return 1;
        }
        if as_json {
            _emit(
                json.dumps(
                    {"name": g.name, "description": g.description, "body": g.body},
                    indent=2
                )
            );
        } else {
            _emit(g.body);
        }
        return 0;
    }

    if search {
        return _search_guides(search, as_json);
    }

    if as_json {
        _emit(json.dumps(_index_payload(), indent=2));
        return 0;
    }

    groups = grouped_guides();
    if not groups {
        console.error("No guides are bundled with this Jac installation.");
        return 0;
    }
    console.print();
    console.print("Jac reference guides", style="bold");
    for (group, members) in groups {
        console.print();
        console.print(f"{group}:", style="bold");
        _print_entries(members);
    }
    corpora = doc_corpora();
    if corpora {
        console.print();
        console.print("Bundled documentation:", style="bold");
        for (ns, members) in corpora {
            console.print(f"  {ns}/ ({len(members)} docs)", style="bold cyan");
            console.print(f"      {corpus_blurb(ns)}", style="muted");
        }
    }
    console.print();
    console.print("Read a guide or doc:  jac guide <name>", style="muted");
    if corpora {
        sets = " | ".join([ns for (ns, _) in corpora]);
        console.print(f"List a doc set:       jac guide {sets}", style="muted");
    }
    console.print("Search everything:    jac guide --search <keywords>", style="muted");
    console.print("Full index as JSON:   jac guide --json", style="muted");
    console.print();
    return 0;
}
