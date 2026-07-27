import from pathlib { Path }
import json;
import from urllib.request { urlopen, Request }
import from urllib.error { URLError }
import from functools { lru_cache }

glob GITHUB_API_BASE: str = "https://api.github.com/repos/jaseci-labs/jaseci",
     GITHUB_CACHE_MAXSIZE: int = 64;

impl find_repo_root -> str | None {
    starts: list[Path] = [Path.cwd(), Path(__file__).parent];
    for start in starts {
        chain = [start] + list(start.parents);
        for parent in chain {
            if (parent / "docs" / "docs").is_dir()
            and (parent / "jac" / "jaclang").is_dir() {
                return str(parent);
            }
        }
    }
    return None;
}

impl ResourceProvider._ensure_indexed -> None {
    if not self._indexed {
        self.index_resources();
    }
}

glob _provider_cache: dict = {};

impl get_resource_provider -> ResourceProvider {
    if "instance" not in _provider_cache {
        _provider_cache["instance"] = ResourceProvider();
    }
    return _provider_cache["instance"];
}

impl ResourceProvider.index_resources -> None {
    if self._indexed {
        return;
    }
    self._package_dir = str(Path(__file__).parent);
    self._repo_root = find_repo_root();
    self._resources = {};

    self._index_grammar();
    self._index_bundled();
    self._index_shared_guides();

    examples_dir = Path(self._repo_root) / "jac" / "examples"
        if self._repo_root
        else None;
    if examples_dir is not None and examples_dir.exists() {
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
    self._indexed = True;
}

impl ResourceProvider._index_grammar -> None {
    import jaclang;
    jaclang_dir = Path(jaclang.__file__).parent;
    spec_path = jaclang_dir / "jac.spec";
    if spec_path.exists() {
        self._resources["jac://grammar/spec"] = {
            "uri": "jac://grammar/spec",
            "name": "Jac Grammar Specification",
            "description": "Full EBNF grammar for the Jac language",
            "mimeType": "text/plain",
            "path": str(spec_path)
        };
    }
    tokens_path = jaclang_dir / "jac0core" / "parser" / "tokens.na.jac";
    if tokens_path.exists() {
        self._resources["jac://grammar/tokens"] = {
            "uri": "jac://grammar/tokens",
            "name": "Jac Token Definitions",
            "description": "Token definitions and keywords for the Jac language",
            "mimeType": "text/plain",
            "path": str(tokens_path)
        };
    }
}

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
    understand_path = content_dir / "understand.md";
    if understand_path.exists() {
        self._resources["jac://guide/understand"] = {
            "uri": "jac://guide/understand",
            "name": "Jac & Jaseci Knowledge Map",
            "description": "Orientation map: what Jac and Jaseci are, the 3 core paradigms, and which resource URI to fetch for any task",
            "mimeType": "text/markdown",
            "path": str(understand_path)
        };
    }
}

impl ResourceProvider._index_shared_guides -> None {
    try {
        import from jaclang.cli.guide_store { list_guides }
    } except ImportError {
        return;
    }
    for g in list_guides() {
        uri = f"jac://guide/{g.name}";
        self._resources[uri] = {
            "uri": uri,
            "name": g.name,
            "description": g.description,
            "mimeType": "text/markdown",
            "path": g.path
        };
    }
}

impl ResourceProvider.list_resources -> list[dict[str, str]] {
    self._ensure_indexed();
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

impl ResourceProvider.read_resource(uri: str) -> str {
    self._ensure_indexed();
    if uri.startswith("jac://examples/") {
        return self._read_example(uri);
    }
    if uri not in self._resources {
        return f"Error: Resource not found: {uri}";
    }
    info = self._resources[uri];

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

impl ResourceProvider._read_example(uri: str) -> str {
    info = self._resources.get(uri);

    if info and info.get("_is_dir", False) {
        return _read_example_dir(info["path"]);
    }

    if uri == "jac://examples/index" {
        if info and "_categories" in info {
            categories = info["_categories"];
        } else {
            categories = self._fetch_github_categories();
        }
        lines: list[str] = ["# Jac Examples Index\n"];
        for cat in categories {
            lines.append(f"- jac://examples/{cat}");
        }
        return "\n".join(lines);
    }

    example_name = uri.replace("jac://examples/", "");
    if not example_name {
        return "Error: Invalid example URI";
    }
    return _fetch_example_github(f"jac/examples/{example_name}");
}

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

def _github_api_get(url: str) -> any {
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

impl ResourceProvider._index_examples_local(examples_dir: Path) -> None {
    EXAMPLE_DESCRIPTIONS: dict[str, str] = {
        "chess": "Native chess engine, backend-only, no graph traversal. Demonstrates declaration/impl separation, enums, obj inheritance, and the Jac type system.",
        "littleX": "Full-stack social app (Twitter-like), OSP graph with user profiles and NLP-based search (sklearn/TF-IDF). Real-world object-spatial design."
    };
    categories: list[str] = [];
    for entry in sorted(examples_dir.iterdir()) {
        if entry.is_dir()
        and not entry.name.startswith(".")
        and not entry.name.startswith("_") {
            categories.append(entry.name);
            desc = EXAMPLE_DESCRIPTIONS.get(
                entry.name, f"Example Jac code for {entry.name}"
            );
            self._resources[f"jac://examples/{entry.name}"] = {
                "uri": f"jac://examples/{entry.name}",
                "name": f"Example: {entry.name}",
                "description": desc,
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

    self._resources["jac://examples/index"]["_categories"] = categories;
    return categories;
}

@lru_cache(maxsize=GITHUB_CACHE_MAXSIZE)
def _fetch_example_github(github_path: str) -> str {
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
    return result;
}

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
