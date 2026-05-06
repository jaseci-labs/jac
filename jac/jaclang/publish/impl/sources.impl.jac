"""Implementation of the source file collector."""

import fnmatch;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }

def _is_excluded(file_path: Path, pkg_root: Path) -> bool {
    # Check every path component for excluded directory names
    try {
        rel = file_path.relative_to(pkg_root);
    } except ValueError {
        return False;
    }
    for part in rel.parts[:-1] {  # skip the filename itself
        if part in EXCLUDED_DIRS {
            return True;
        }
        # Also skip egg-info directories (e.g. byllm.egg-info/)
        if part.endswith(".egg-info") {
            return True;
        }
    }
    # Check the suffix of the file itself
    for suffix in EXCLUDED_SUFFIXES {
        if file_path.name.endswith(suffix) {
            return True;
        }
    }
    return False;
}

def _make_recursive(pattern: str) -> str {
    # Simple filename patterns like "*.jac" or "*.py" (no path separator,
    # no ** prefix) must be made recursive so that sub-directories like
    # jac_client/plugin/ are also covered — mirroring how pip applies
    # package-data patterns to each discovered sub-package.
    if "/" not in pattern and not pattern.startswith("**") {
        return f"**/{pattern}";
    }
    return pattern;
}

def _collect_from_dir(
    pkg_dir: Path, root: Path, patterns: list[str], seen: set,
) -> list[SourceFile] {
    result: list[SourceFile] = [];

    for pattern in patterns {
        effective = _make_recursive(pattern);
        for file_path in sorted(pkg_dir.glob(effective)) {
            if not file_path.is_file() {
                continue;
            }
            if _is_excluded(file_path, pkg_dir) {
                continue;
            }
            # Wheel-relative path uses forward slashes
            wheel_path = str(file_path.relative_to(root)).replace("\\", "/");
            if wheel_path in seen {
                continue;
            }
            seen.add(wheel_path);
            result.append(SourceFile(wheel_path=wheel_path, source_path=file_path));
        }
    }

    return result;
}

impl read_source_file(sf: SourceFile) -> bytes {
    if sf.content is not None {
        return sf.content;
    }
    if sf.source_path is not None {
        sf.content = sf.source_path.read_bytes();
        return sf.content;
    }
    raise ValueError(
        f"SourceFile '{sf.wheel_path}' has neither content nor source_path set."
    );
}

impl collect_source_files(
    config: JacConfig, project_root: Path | None = None,
) -> list[SourceFile] {
    root = project_root or config.project_root;
    if root is None {
        raise ValueError(
            "project_root is required: pass it explicitly or ensure "
            "config.project_root is set."
        );
    }

    if config.package is None {
        raise ValueError(
            "Cannot collect source files: [package] section is missing in jac.toml."
        );
    }

    pkg_include = config.package.include;
    data_map = pkg_include.data;

    # Global patterns: "*" key overrides defaults; if absent, defaults apply.
    global_patterns: list[str] = list(data_map.get("*", DEFAULT_INCLUDE_PATTERNS));

    seen: set = set();
    result: list[SourceFile] = [];

    # ── Discover package directories ─────────────────────────────────────────
    package_patterns = pkg_include.packages;

    # When no explicit packages list is given, fall back to a directory whose
    # name matches the package name (normalized: hyphens → underscores).
    if not package_patterns and config.package.name {
        package_patterns = [config.package.name.replace("-", "_")];
    }

    candidates = sorted(
        c
        for c in root.iterdir()
        if c.is_dir() and c.name not in EXCLUDED_DIRS
    );

    for pkg_glob in package_patterns {
        for candidate in candidates {
            if not fnmatch.fnmatch(candidate.name, pkg_glob) {
                continue;
            }

            # Combine global patterns with any package-specific ones
            specific: list[str] = list(data_map.get(candidate.name, []));
            patterns = global_patterns + specific;

            pkg_files = _collect_from_dir(candidate, root, patterns, seen);
            result.extend(pkg_files);
        }
    }

    return result;
}
