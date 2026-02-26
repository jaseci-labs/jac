"""Bundle documentation for PyPI release.

Reads DOC_MAPPINGS directly from the resources module (single source of truth)
and copies each referenced doc file into jac_mcp/content/docs/ with its
bundled filename. Also copies grammar files (jac.spec, tokens.jac).

Usage (from jac-mcp/ directory):
    jac run scripts/bundle_docs.jac
"""

import shutil;
import sys;

import from pathlib { Path }
import from jac_mcp.resources { find_repo_root, DOC_MAPPINGS }

"""Grammar files to copy (source relative to repo root, destination filename)."""
glob GRAMMAR_FILES: list[tuple] = [
         ("jac/jaclang/jac.spec", "jac-grammar.spec"),
         ("jac/jaclang/jac0core/parser/tokens.jac", "tokens.jac"),

     ],
     w = sys.stdout.write;

"""Run the bundling pipeline."""
def main -> int {
    repo_root = find_repo_root();
    if repo_root is None {
        w("ERROR: Could not find repo root (jaclang not installed?)\n");
        return 1;
    }
    repo = Path(repo_root);
    docs_src = repo / "docs" / "docs";
    bundle_dst = repo / "jac-mcp" / "jac_mcp" / "content" / "docs";

    w(f"Repo root: {repo}\n");
    w(f"DOC_MAPPINGS: {len(DOC_MAPPINGS)} entries\n\n");

    # Create output directory
    bundle_dst.mkdir(parents=True, exist_ok=True);

    copied = 0;
    missing: list[tuple] = [];

    # Copy documentation files
    for (uri, mapping) in DOC_MAPPINGS.items() {
        (rel_path, bundled_name, desc) = mapping;
        src = docs_src / rel_path;
        dst = bundle_dst / bundled_name;

        if src.exists() {
            shutil.copy2(str(src), str(dst));
            copied += 1;
            w(f"  OK   {rel_path} -> {bundled_name}\n");
        } else {
            missing.append((rel_path, bundled_name));
            w(f"  MISS {rel_path}\n");
        }
    }

    # Copy grammar files
    w("\n");
    for (src_rel, dst_name) in GRAMMAR_FILES {
        src = repo / src_rel;
        dst = bundle_dst / dst_name;

        if src.exists() {
            shutil.copy2(str(src), str(dst));
            copied += 1;
            w(f"  OK   {src_rel} -> {dst_name}\n");
        } else {
            missing.append((src_rel, dst_name));
            w(f"  MISS {src_rel}\n");
        }
    }

    # Summary
    w(f"\nBundled: {copied} files -> {bundle_dst}\n");
    if missing {
        w(f"Missing: {len(missing)} files:\n");
        for (rel, name) in missing {
            w(f"  - {rel} (expected as {name})\n");
        }
        return 1;
    }

    w("All files bundled successfully.\n");
    return 0;
}

with entry {
    sys.exit(main());
}
