"""Implementation of resource providers."""

import from typing { Any }
import from pathlib { Path }
import json;
import from urllib.request { urlopen, Request }
import from urllib.error { URLError }

glob GITHUB_API_BASE: str = "https://api.github.com/repos/jaseci-labs/jaseci",
     _github_cache: dict[str, str] = {};

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
         # --- Get Started ---
         "jac://docs/welcome": (
             "quick-guide/index.md",
             "quick-guide-index.md",
             "Welcome - Getting started with Jac"
         ),
         "jac://docs/install": (
             "quick-guide/install.md",
             "install.md",
             "Installation - Setting up Jac"
         ),
         "jac://docs/core-concepts": (
             "quick-guide/what-makes-jac-different.md",
             "what-makes-jac-different.md",
             "Core Concepts - What makes Jac different"
         ),
         "jac://docs/first-app": (
             "tutorials/first-app/build-ai-day-planner.md",
             "build-ai-day-planner.md",
             "Build to Learn - AI Day Planner tutorial"
         ),
         "jac://docs/cheatsheet": (
             "quick-guide/syntax-cheatsheet.md",
             "syntax-cheatsheet.md",
             "Syntax Cheatsheet - Quick reference"
         ),
         "jac://docs/jac-vs-traditional": (
             "quick-guide/jac-vs-traditional-stack.md",
             "jac-vs-traditional-stack.md",
             "Jac vs Traditional Stack - Architecture comparison"
         ),
         "jac://docs/faq": (
             "quick-guide/faq.md",
             "faq.md",
             "FAQ - Frequently asked questions"
         ),
         # --- Language Specification ---
         "jac://docs/reference-overview": (
             "reference/index.md",
             "reference-index.md",
             "Reference Overview - Full reference index"
         ),
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
         # --- Learn by Doing: Language ---
         "jac://docs/tutorial-coding-primer": (
             "tutorials/language/coding_primer.md",
             "coding_primer.md",
             "New to Programming? - Coding primer for beginners"
         ),
         "jac://docs/tutorial-basics": (
             "tutorials/language/basics.md",
             "basics.md",
             "Jac Fundamentals - Language basics tutorial"
         ),
         "jac://docs/tutorial-osp": (
             "tutorials/language/osp.md",
             "tutorial-osp.md",
             "Graphs & Walkers - OSP tutorial"
         ),
         # --- Native Compilation ---
         "jac://docs/native-pathway": (
             "reference/language/native-pathway.md",
             "native-pathway.md",
             "Native Compilation - Native pathway reference"
         ),
         "jac://docs/tutorial-native-chess": (
             "tutorials/native/chess.md",
             "native-chess.md",
             "Build a Chess Engine - Native compilation tutorial"
         ),
         # --- AI Integration ---
         "jac://docs/byllm": (
             "reference/plugins/byllm.md",
             "byllm.md",
             "byLLM - LLM integration reference"
         ),
         "jac://docs/tutorial-ai-quickstart": (
             "tutorials/ai/quickstart.md",
             "ai-quickstart.md",
             "Your First AI Function - AI quickstart tutorial"
         ),
         "jac://docs/tutorial-ai-structured": (
             "tutorials/ai/structured-outputs.md",
             "ai-structured-outputs.md",
             "Structured Outputs - AI structured output tutorial"
         ),
         "jac://docs/tutorial-ai-agentic": (
             "tutorials/ai/agentic.md",
             "ai-agentic.md",
             "Agentic AI - Building AI agents tutorial"
         ),
         "jac://docs/tutorial-ai-multimodal": (
             "tutorials/ai/multimodal.md",
             "ai-multimodal.md",
             "Multimodal - Multimodal AI tutorial"
         ),
         # --- Full-Stack Development ---
         "jac://docs/jac-client": (
             "reference/plugins/jac-client.md",
             "jac-client.md",
             "jac-client - Full-stack web reference"
         ),
         "jac://docs/tutorial-fullstack-setup": (
             "tutorials/fullstack/setup.md",
             "fullstack-setup.md",
             "Project Setup - Full-stack setup tutorial"
         ),
         "jac://docs/tutorial-fullstack-components": (
             "tutorials/fullstack/components.md",
             "fullstack-components.md",
             "Components - Full-stack components tutorial"
         ),
         "jac://docs/tutorial-fullstack-state": (
             "tutorials/fullstack/state.md",
             "fullstack-state.md",
             "State Management - Full-stack state tutorial"
         ),
         "jac://docs/tutorial-fullstack-backend": (
             "tutorials/fullstack/backend.md",
             "fullstack-backend.md",
             "Backend Integration - Full-stack backend tutorial"
         ),
         "jac://docs/tutorial-fullstack-auth": (
             "tutorials/fullstack/auth.md",
             "fullstack-auth.md",
             "Authentication - Full-stack auth tutorial"
         ),
         "jac://docs/tutorial-fullstack-routing": (
             "tutorials/fullstack/routing.md",
             "fullstack-routing.md",
             "Routing - Full-stack routing tutorial"
         ),
         # --- Deployment & Scaling ---
         "jac://docs/jac-scale": (
             "reference/plugins/jac-scale.md",
             "jac-scale.md",
             "jac-scale - Deployment/scaling reference"
         ),
         "jac://docs/tutorial-production-local": (
             "tutorials/production/local.md",
             "production-local.md",
             "Local API Server - Local deployment tutorial"
         ),
         "jac://docs/tutorial-production-k8s": (
             "tutorials/production/kubernetes.md",
             "production-kubernetes.md",
             "Kubernetes - Kubernetes deployment tutorial"
         ),
         # --- Developer Workflow ---
         "jac://docs/cli": (
             "reference/cli/index.md",
             "cli-index.md",
             "CLI Commands - Command line interface reference"
         ),
         "jac://docs/config": (
             "reference/config/index.md",
             "config-index.md",
             "Configuration - Project configuration reference"
         ),
         "jac://docs/code-organization": (
             "reference/code-organization.md",
             "code-organization.md",
             "Code Organization - Project structure guide"
         ),
         "jac://docs/mcp": (
             "quick-guide/mcp.md",
             "mcp.md",
             "MCP Server - Model Context Protocol reference"
         ),
         "jac://docs/testing": (
             "reference/testing.md",
             "testing.md",
             "Testing - Test framework reference"
         ),
         "jac://docs/debugging": (
             "tutorials/language/debugging.md",
             "debugging.md",
             "Debugging - Debugging techniques tutorial"
         ),
         # --- Python Integration ---
         "jac://docs/python-integration": (
             "reference/language/python-integration.md",
             "python-integration.md",
             "Python Integration - Interop with Python"
         ),
         "jac://docs/library-mode": (
             "reference/language/library-mode.md",
             "library-mode.md",
             "Library Mode - Using Jac as a library"
         ),
         # --- Quick Reference ---
         "jac://docs/walker-responses": (
             "reference/language/walker-responses.md",
             "walker-responses.md",
             "Walker Patterns - Walker response patterns"
         ),
         "jac://docs/appendices": (
             "reference/language/appendices.md",
             "appendices.md",
             "Appendices - Additional language reference"
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
        # Examples fetched lazily from GitHub on first access
        self._resources["jac://examples/index"] = {
            "uri": "jac://examples/index",
            "name": "Examples Index",
            "description": "Index of all available Jac code examples",
            "mimeType": "text/plain",
            "_is_lazy_github": True
        };
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
    tokens_path = repo_root / "jac" / "jaclang" / "jac0core" / "parser" / "tokens.na.jac";
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
    # Examples — prefer local repo, fall back to lazy GitHub
    examples_dir = repo_root / "jac" / "examples";
    if examples_dir.exists() {
        self._index_examples_local(examples_dir);
    } else {
        self._resources["jac://examples/index"] = {
            "uri": "jac://examples/index",
            "name": "Examples Index",
            "description": "Index of all available Jac code examples",
            "mimeType": "text/plain",
            "_is_lazy_github": True
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
    tokens_path = docs_dir / "tokens.na.jac";
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
    # Handle lazy GitHub examples (registered or on-demand)
    if uri.startswith("jac://examples/") {
        return self._read_example(uri);
    }
    if uri not in self._resources {
        return f"Error: Resource not found: {uri}";
    }
    info = self._resources[uri];
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

"""Read example resource — handles local dirs, lazy GitHub index, and on-demand GitHub fetch."""
impl ResourceProvider._read_example(uri: str) -> str {
    info = self._resources.get(uri);
    # Local directory example
    if info and info.get("_is_dir", False) {
        return _read_example_dir(info["path"]);
    }
    # Lazy GitHub index — fetch categories on first access
    if uri == "jac://examples/index" {
        if info and "_categories" in info {
            # Already populated
            categories = info["_categories"];
        } else {
            # Fetch from GitHub
            categories = self._fetch_github_categories();
        }
        lines: list[str] = ["# Jac Examples Index\n"];
        for cat in categories {
            lines.append(f"- jac://examples/{cat}");
        }
        return "\n".join(lines);
    }
    # Specific example — local info exists with categories but not this one,
    # or it's a GitHub-sourced example
    example_name = uri.replace("jac://examples/", "");
    if not example_name {
        return "Error: Invalid example URI";
    }
    return _fetch_example_github(f"jac/examples/{example_name}");
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

"""Fetch JSON from a URL, returns parsed dict/list or None on failure."""
def _github_api_get(url: str) -> Any {
    try {
        req = Request(
            url,
            headers={
                "Accept": "application/vnd.github.v3+json",
                "User-Agent": "jac-mcp"
            }
        );
        with urlopen(req, timeout=10) as resp {
            return json.loads(resp.read().decode());
        }
    } except (URLError, json.JSONDecodeError, OSError) {
        return None;
    }
}

"""Index examples by listing local directories."""
impl ResourceProvider._index_examples_local(examples_dir: Path) -> None {
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

"""Fetch example categories from GitHub and cache them."""
impl ResourceProvider._fetch_github_categories -> list[str] {
    data = _github_api_get(f"{GITHUB_API_BASE}/contents/jac/examples");
    if data is None or not isinstance(data, list) {
        return [];
    }
    categories: list[str] = [
        item["name"]
        for item in data
        if item.get("type") == "dir"
        and not item["name"].startswith(".")
        and not item["name"].startswith("_")
    ];
    # Cache on the index resource so we don't re-fetch
    self._resources["jac://examples/index"]["_categories"] = categories;
    return categories;
}

"""Fetch all .jac files from a GitHub directory using contents API."""
def _fetch_example_github(github_path: str) -> str {
    if github_path in _github_cache {
        return _github_cache[github_path];
    }
    jac_files = _list_jac_files_recursive(github_path);
    if not jac_files {
        return "No .jac files found or GitHub API unavailable.";
    }
    result_parts: list[str] = [];
    for (rel_path, download_url) in sorted(jac_files) {
        try {
            req = Request(download_url, headers={"User-Agent": "jac-mcp"});
            with urlopen(req, timeout=10) as resp {
                content = resp.read().decode();
            }
            result_parts.append(f"--- {rel_path} ---\n{content}");
        } except (URLError, OSError) {
            result_parts.append(f"--- {rel_path} ---\nError: failed to fetch");
        }
    }
    result = "\n\n".join(result_parts) if result_parts else "No .jac files found.";
    _github_cache[github_path] = result;
    return result;
}

"""Recursively list .jac files in a GitHub directory via contents API.
Returns list of (relative_path, download_url) tuples."""
def _list_jac_files_recursive(github_path: str, base_path: str = "") -> list[tuple] {
    data = _github_api_get(f"{GITHUB_API_BASE}/contents/{github_path}");
    if data is None or not isinstance(data, list) {
        return [];
    }
    results: list[tuple] = [];
    for item in data {
        name = item.get("name", "");
        rel = f"{base_path}/{name}" if base_path else name;
        if item.get("type") == "file" and name.endswith(".jac") {
            results.append((rel, item.get("download_url", "")));
        } elif item.get("type") == "dir"
        and not name.startswith(".")
        and not name.startswith("_") {
            results.extend(_list_jac_files_recursive(item["path"], rel));
        }
    }
    return results;
}
