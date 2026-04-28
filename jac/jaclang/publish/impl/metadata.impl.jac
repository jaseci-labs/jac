"""Implementation of the METADATA file generator."""

import re;
import from pathlib { Path }
import from jaclang.project.config { JacConfig, PackageConfig, PersonConfig }

# ===============================================================================
# normalize_package_name
# ===============================================================================
impl normalize_package_name(name: str) -> str {
    return re.sub(r"[-_.]+", "-", name).lower();
}

# ===============================================================================
# build_person_header
# ===============================================================================
impl build_person_header(persons: list[PersonConfig]) -> str {
    parts: list[str] = [];
    for p in persons {
        if p.name and p.email {
            parts.append(f"{p.name} <{p.email}>");
        } elif p.email {
            parts.append(p.email);
        } elif p.name {
            parts.append(p.name);
        }
    }
    return ", ".join(parts);
}

# ===============================================================================
# normalize_constraint
# ===============================================================================
impl normalize_constraint(raw: str) -> str {
    raw = raw.strip();

    # Unconstrained
    if not raw or raw in ("*", "latest") {
        return "";
    }

    # npm caret: ^MAJOR[.MINOR[.PATCH]]
    if raw.startswith("^") {
        ver_str = raw[1:];
        parts = ver_str.split(".");
        try {
            major = int(parts[0]) if parts else 0;
            minor = int(parts[1]) if len(parts) > 1 else 0;
            patch = int(parts[2]) if len(parts) > 2 else 0;
        } except ValueError {
            return raw;
        }
        padded = ".".join(parts + ["0"] * (3 - len(parts)));
        if major > 0 {
            return f">={padded},<{major + 1}.0.0";
        } elif minor > 0 {
            return f">={padded},<{major}.{minor + 1}.0";
        } else {
            return f">={padded},<{major}.{minor}.{patch + 1}";
        }
    }

    # npm tilde: ~MAJOR.MINOR  (NOT Python ~= compatible-release)
    if raw.startswith("~") and not raw.startswith("~=") {
        ver_str = raw[1:];
        parts = ver_str.split(".");
        try {
            major = int(parts[0]) if parts else 0;
            minor = int(parts[1]) if len(parts) > 1 else 0;
        } except ValueError {
            return raw;
        }
        padded = ".".join(parts + ["0"] * (3 - len(parts)));
        return f">={padded},<{major}.{minor + 1}.0";
    }

    # PEP 440 specifier operators → pass through unchanged
    if raw and raw[0] in (">", "<", "!", "~", "=") {
        return raw;
    }

    # Bare version number → exact match
    if re.match(r"^\d", raw) {
        return f"=={raw}";
    }

    return raw;
}

# ===============================================================================
# build_requires_dist
# ===============================================================================
impl build_requires_dist(name: str, raw_ver: str, extra: str | None = None) -> str {
    spec = normalize_constraint(raw_ver);
    dep = normalize_package_name(name);
    if spec {
        dep = f"{dep}{spec}";
    }
    if extra is not None {
        dep = f'{dep}; extra == "{extra}"';
    }
    return dep;
}

# ===============================================================================
# readme_content_type
# ===============================================================================
impl readme_content_type(readme_filename: str) -> str {
    ext = Path(readme_filename).suffix.lower();
    if ext == ".md" {
        return "text/markdown";
    } elif ext == ".rst" {
        return "text/x-rst";
    } else {
        return "text/plain";
    }
}

# ===============================================================================
# generate_metadata
# ===============================================================================
impl generate_metadata(config: JacConfig, project_root: Path | None = None) -> str {
    if config.package is None {
        raise ValueError(
            "Cannot generate METADATA: [package] section is missing in jac.toml"
        );
    }

    pkg = config.package;
    root = project_root or config.project_root;
    lines: list[str] = [];

    # Append 'Header: value' only when value is non-empty
    def h(hdr: str, value: str) {
        if value {
            lines.append(f"{hdr}: {value}");
        }
    }

    # ── Required headers ────────────────────────────────────────────────────
    h("Metadata-Version", METADATA_VERSION);
    h("Name", normalize_package_name(pkg.name));
    h("Version", pkg.version);

    # ── Optional descriptive headers ────────────────────────────────────────
    h("Summary", pkg.description);

    author_val = build_person_header(pkg.authors);
    if author_val {
        h("Author-email", author_val);
    }

    maintainer_val = build_person_header(pkg.maintainers);
    if maintainer_val {
        h("Maintainer-email", maintainer_val);
    }

    # License-Expression is the Metadata 2.4 field (PEP 639).
    if pkg.license {
        h("License-Expression", pkg.license);
    }

    if pkg.keywords {
        h("Keywords", ",".join(pkg.keywords));
    }

    h("Requires-Python", pkg.requires_python);

    # ── Project URLs ─────────────────────────────────────────────────────────
    for (label, url) in pkg.urls.items() {
        lines.append(f"Project-URL: {label.capitalize()}, {url}");
    }

    # ── Runtime dependencies ─────────────────────────────────────────────────
    for (dep_name, raw_ver) in config.dependencies.items() {
        h("Requires-Dist", build_requires_dist(dep_name, raw_ver));
    }

    # ── Optional dependency groups ────────────────────────────────────────────
    # Emit all Provides-Extra headers first so parsers see them before markers.
    for group in config.optional_dependencies {
        h("Provides-Extra", group);
    }
    for (group, deps) in config.optional_dependencies.items() {
        for (dep_name, raw_ver) in deps.items() {
            h("Requires-Dist", build_requires_dist(dep_name, raw_ver, extra=group));
        }
    }

    # ── README body ───────────────────────────────────────────────────────────
    readme_content: str | None = None;
    if pkg.readme and root {
        readme_path = root / pkg.readme;
        if readme_path.exists() {
            h("Description-Content-Type", readme_content_type(pkg.readme));
            readme_content = readme_path.read_text(encoding="utf-8");
        }
    }

    # Blank line separates header block from body (RFC 822).
    lines.append("");
    if readme_content {
        lines.append(readme_content);
    }

    return "\n".join(lines);
}

# ===============================================================================
# parse_metadata
# ===============================================================================
impl parse_metadata(text: str) -> dict[str, list[str]] {
    result: dict[str, list[str]] = {};
    lines = text.splitlines();
    body_start: int | None = None;

    for (i, line) in enumerate(lines) {
        if line == "" {
            body_start = i + 1;
            break;
        }
        if ": " in line {
            (key, _, value) = line.partition(": ");
            if key not in result {
                result[key] = [];
            }
            result[key].append(value);
        }
    }

    if body_start is not None {
        result["body"] = ["\n".join(lines[body_start:])];
    }

    return result;
}
