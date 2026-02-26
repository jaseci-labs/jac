"""Implementation of resource providers."""

import from typing { Any }
import from pathlib { Path }

"""Find the repo root by walking up from jaclang package location."""
impl find_repo_root -> str | None {
    try {
        import jaclang;
        pkg_dir = Path(jaclang.__file__).parent;
        # Check if jac.spec is in the package dir (editable install)
        check = pkg_dir / "jac.spec";
        if check.exists() {
            # pkg_dir is jac/jaclang, repo root is 2 levels up
            return str(pkg_dir.parent.parent);
        }
        # Walk up looking for the spec
        for parent in pkg_dir.parents {
            spec = parent / "jac" / "jaclang" / "jac.spec";
            if spec.exists() {
                return str(parent);
            }
        }
    } except Exception {
        # Silently ignore if jaclang not available
        return None;
    }
    return None;
}

"""Mapping from URI to (relative doc path, bundled filename, description)."""
glob DOC_MAPPINGS: dict[str, tuple] = {
         "jac://docs/foundation": (
             "reference/language/foundation.md",
             "foundation.md",
             "Foundation - Core language concepts"
         ),
         "jac://docs/primitives": (
             "reference/language/primitives.md",
             "primitives.md",
             "Primitives & Codespace Semantics"
         ),
         "jac://docs/functions-objects": (
             "reference/language/functions-objects.md",
             "functions-objects.md",
             "Functions & Objects - Archetypes, abilities, has"
         ),
         "jac://docs/osp": (
             "reference/language/osp.md",
             "osp.md",
             "Object-Spatial Programming - Nodes, edges, walkers"
         ),
         "jac://docs/concurrency": (
             "reference/language/concurrency.md",
             "concurrency.md",
             "Concurrency - flow, wait, async"
         ),
         "jac://docs/advanced": (
             "reference/language/advanced.md",
             "advanced.md",
             "Comprehensions & Filters"
         ),
         "jac://docs/cheatsheet": (
             "quick-guide/syntax-cheatsheet.md",
             "syntax-cheatsheet.md",
             "Syntax Cheatsheet - Quick reference"
         ),
         "jac://docs/python-integration": (
             "reference/language/python-integration.md",
             "python-integration.md",
             "Python Integration - Interop with Python"
         ),
         "jac://docs/byllm": (
             "reference/plugins/byllm.md",
             "byllm.md",
             "byLLM - LLM integration reference"
         ),
         "jac://docs/jac-client": (
             "reference/plugins/jac-client.md",
             "jac-client.md",
             "jac-client - Full-stack web reference"
         ),
         "jac://docs/jac-scale": (
             "reference/plugins/jac-scale.md",
             "jac-scale.md",
             "jac-scale - Deployment/scaling reference"
         ),

     };

"""Scan paths and build URI to filepath mapping."""
impl ResourceProvider.index_resources -> None {
    self._package_dir = str(Path(__file__).parent);
    self._repo_root = find_repo_root();
    self._resources = {};
    if self._repo_root is None {
        # PyPI install — bundled content + bundled docs
        self._index_bundled();
        self._index_bundled_docs();
        return;
    }
    repo_root = Path(self._repo_root);
    # Grammar resources
    spec_path = repo_root / "jac" / "jaclang" / "jac.spec";
    if spec_path.exists() {
        self._resources["jac://grammar/spec"] = {
            "uri": "jac://grammar/spec",
            "name": "Jac Grammar Specification",
            "description": "Full EBNF grammar for the Jac language",
            "mimeType": "text/plain",
            "path": str(spec_path)
        };
    }
    tokens_path = repo_root / "jac" / "jaclang" / "jac0core" / "parser" / "tokens.jac";
    if tokens_path.exists() {
        self._resources["jac://grammar/tokens"] = {
            "uri": "jac://grammar/tokens",
            "name": "Jac Token Definitions",
            "description": "Token definitions and keywords for the Jac language",
            "mimeType": "text/plain",
            "path": str(tokens_path)
        };
    }
    # Documentation resources (from repo docs/)
    for (uri, mapping) in DOC_MAPPINGS.items() {
        (rel_path, _, desc) = mapping;
        full_path = repo_root / "docs" / "docs" / rel_path;
        if full_path.exists() {
            name = desc.split(" - ")[0] if " - " in desc else desc;
            self._resources[uri] = {
                "uri": uri,
                "name": name,
                "description": desc,
                "mimeType": "text/markdown",
                "path": str(full_path)
            };
        }
    }
    # Bundled content (always available)
    self._index_bundled();
    # Examples
    examples_dir = repo_root / "jac" / "examples";
    if examples_dir.exists() {
        categories: list[str] = [];
        for entry in sorted(examples_dir.iterdir()) {
            if entry.is_dir()
            and not entry.name.startswith(".")
            and not entry.name.startswith("_") {
                categories.append(entry.name);
                self._resources[f"jac://examples/{entry.name}"] = {
                    "uri": f"jac://examples/{entry.name}",
                    "name": f"Example: {entry.name}",
                    "description": f"Example Jac code for {entry.name}",
                    "mimeType": "text/plain",
                    "path": str(entry),
                    "_is_dir": True
                };
            }
        }
        self._resources["jac://examples/index"] = {
            "uri": "jac://examples/index",
            "name": "Examples Index",
            "description": "Index of all available Jac code examples",
            "mimeType": "text/plain",
            "_categories": categories
        };
    }
}

"""Index bundled content (pitfalls, patterns)."""
impl ResourceProvider._index_bundled -> None {
    pkg = Path(self._package_dir);
    content_dir = pkg / "content";
    pitfalls_path = content_dir / "pitfalls.md";
    if pitfalls_path.exists() {
        self._resources["jac://guide/pitfalls"] = {
            "uri": "jac://guide/pitfalls",
            "name": "Jac Pitfalls Guide",
            "description": "Common mistakes AI models make when writing Jac code",
            "mimeType": "text/markdown",
            "path": str(pitfalls_path)
        };
    }
    patterns_path = content_dir / "patterns.md";
    if patterns_path.exists() {
        self._resources["jac://guide/patterns"] = {
            "uri": "jac://guide/patterns",
            "name": "Jac Patterns Guide",
            "description": "Idiomatic Jac code patterns with complete examples",
            "mimeType": "text/markdown",
            "path": str(patterns_path)
        };
    }
}

"""Index bundled docs copied at release time."""
impl ResourceProvider._index_bundled_docs -> None {
    docs_dir = Path(self._package_dir) / "content" / "docs";
    if not docs_dir.exists() {
        return;
    }
    # Grammar spec
    spec_path = docs_dir / "jac-grammar.spec";
    if spec_path.exists() {
        self._resources["jac://grammar/spec"] = {
            "uri": "jac://grammar/spec",
            "name": "Jac Grammar Specification",
            "description": "Full EBNF grammar for the Jac language",
            "mimeType": "text/plain",
            "path": str(spec_path)
        };
    }
    # Token definitions
    tokens_path = docs_dir / "tokens.jac";
    if tokens_path.exists() {
        self._resources["jac://grammar/tokens"] = {
            "uri": "jac://grammar/tokens",
            "name": "Jac Token Definitions",
            "description": "Token definitions and keywords for the Jac language",
            "mimeType": "text/plain",
            "path": str(tokens_path)
        };
    }
    # Documentation markdown files
    for (uri, mapping) in DOC_MAPPINGS.items() {
        (_, bundled_name, desc) = mapping;
        full_path = docs_dir / bundled_name;
        if full_path.exists() {
            name = desc.split(" - ")[0] if " - " in desc else desc;
            self._resources[uri] = {
                "uri": uri,
                "name": name,
                "description": desc,
                "mimeType": "text/markdown",
                "path": str(full_path)
            };
        }
    }
}

"""Return list of available resources."""
impl ResourceProvider.list_resources -> list[dict[str, str]] {
    result: list[dict[str, str]] = [];
    for uri in sorted(self._resources) {
        info = self._resources[uri];
        result.append(
            {
                "uri": info["uri"],
                "name": info["name"],
                "description": info.get("description", ""),
                "mimeType": info.get("mimeType", "text/plain")
            }
        );
    }
    return result;
}

"""Read resource content by URI."""
impl ResourceProvider.read_resource(uri: str) -> str {
    if uri not in self._resources {
        return f"Error: Resource not found: {uri}";
    }
    info = self._resources[uri];
    # Handle examples index
    if uri == "jac://examples/index" {
        categories = info.get("_categories", []);
        lines: list[str] = ["# Jac Examples Index\n"];
        for cat in categories {
            lines.append(f"- jac://examples/{cat}");
        }
        return "\n".join(lines);
    }
    # Handle example directories
    if info.get("_is_dir", False) {
        return _read_example_dir(info["path"]);
    }
    # Handle regular files
    file_path = info.get("path");
    if not file_path {
        return "Error: No file path for resource";
    }
    try {
        with open(file_path, "r") as f {
            return f.read();
        }
    } except FileNotFoundError {
        return f"Error: File not found: {file_path}";
    } except Exception as e {
        return f"Error reading resource: {e}";
    }
}

"""Read all .jac files from an example directory."""
def _read_example_dir(dir_path: str) -> str {
    result_parts: list[str] = [];
    p = Path(dir_path);
    for jac_file in sorted(p.rglob("*.jac")) {
        rel = jac_file.relative_to(p);
        try {
            content = jac_file.read_text();
            result_parts.append(f"--- {rel} ---\n{content}");
        } except Exception as e {
            result_parts.append(f"--- {rel} ---\nError: {e}");
        }
    }
    if not result_parts {
        return "No .jac files found in this example.";
    }
    return "\n\n".join(result_parts);
}
