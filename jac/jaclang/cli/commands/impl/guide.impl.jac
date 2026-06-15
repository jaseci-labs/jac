"""Implementation of the `jac guide` command."""

import json;
import shutil;
import sys;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.cli.guide_store {
    list_guides,
    get_guide,
    search_guides,
    guide_group,
    grouped_guides
}

"""Write text verbatim to stdout, followed by a newline.

Used for guide bodies and `--json` payloads: `console.print` routes through a
Rich-enhanced console that reflows long lines, which would corrupt fenced code
blocks and JSON. A direct stream write keeps the output byte-exact.
"""
def _emit(text: str) {
    sys.stdout.write(text + "\n");
}

"""Write every guide out as a Claude Code skills directory.

Each guide becomes `<dest>/<name>/SKILL.md` -- the dir-per-skill layout that
Claude Code, Cursor, and the Claude Agent SDK discover and auto-load.
"""
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

"""Show curated Jac reference guides bundled with the compiler.

Guide bodies and `--json` payloads go through `_emit` (a verbatim stream
write) rather than `console.print`, whose Rich backend reflows long lines.
The decorative list view keeps `console`.
"""
impl guide(
    topic: str = "", search: str = "", export: str = "", as_json: bool = False
) -> int {
    # Export every guide as a Claude Code skills directory.
    if export {
        return _export_guides(export);
    }
    # Display a single guide.
    if topic {
        g = get_guide(topic);
        if g is None {
            if as_json {
                _emit(json.dumps({"error": f"Guide '{topic}' not found"}));
            } else {
                console.error(f"No guide named '{topic}'.");
                console.print(
                    "Run 'jac guide' to list available guides.", style="muted"
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
    # Grouped console listing (the default no-arg path) loads guides through
    # grouped_guides() alone, so the skills directory is read once.
    if not search and not as_json {
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
            for g in members {
                console.print(f"  {g.name}", style="bold cyan");
                console.print(f"      {g.description}", style="muted");
            }
        }
        console.print();
        console.print("Read one with:  jac guide <name>", style="muted");
        console.print();
        return 0;
    }
    # JSON listing and --search results.
    guides = search_guides(search) if search else list_guides();
    if as_json {
        payload = [
            {
                "name": g.name,
                "description": g.description,
                "group": guide_group(g.name)
            } for g in guides
        ];
        _emit(json.dumps(payload, indent=2));
        return 0;
    }
    # Only the console search path remains.
    if not guides {
        console.warning(f"No guides match '{search}'.");
        return 0;
    }
    console.print();
    console.print(f"Jac guides matching '{search}'", style="bold");
    # Search results are already a filtered subset -- keep them flat.
    console.print();
    for g in guides {
        console.print(f"  {g.name}", style="bold cyan");
        console.print(f"      {g.description}", style="muted");
    }
    console.print();
    console.print("Read one with:  jac guide <name>", style="muted");
    console.print();
    return 0;
}
