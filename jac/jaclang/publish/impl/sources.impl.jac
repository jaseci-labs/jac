import fnmatch;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }

def _is_excluded(file_path: Path, pkg_root: Path) -> bool {
    if pkg_root.name.endswith(".egg-info") {
        return True;
    }

    try {
        rel = file_path.relative_to(pkg_root);
    } except ValueError {
        return False;
    }
    for part in rel.parts[:-1] {
        if part in EXCLUDED_DIRS {
            return True;
        }

        if part.endswith(".egg-info") {
            return True;
        }
    }

    for suffix in EXCLUDED_SUFFIXES {
        if file_path.name.endswith(suffix) {
            return True;
        }
    }
    return False;
}

def _make_recursive(pattern: str) -> str {
    if "/" not in pattern and not pattern.startswith("**") {
        return f"**/{pattern}";
    }
    return pattern;
}

def _collect_from_dir(
    pkg_dir: Path, proj_root: Path, patterns: list[str], seen: set,
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

            wheel_path = str(file_path.relative_to(proj_root)).replace("\\", "/");
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
    proj_root = project_root or config.project_root;
    if proj_root is None {
        raise ValueError(
            "project_root is required: pass it explicitly or ensure "
            "config.project_root is set."
        );
    }

    if not config.project.name {
        raise ValueError(
            "Cannot collect source files: [project] name is missing in jac.toml."
        );
    }

    pkg_include = config.project.include;
    data_map = pkg_include.data;

    global_patterns: list[str] = list(data_map.get("*", DEFAULT_INCLUDE_PATTERNS));

    seen: set = set();
    result: list[SourceFile] = [];

    package_patterns = pkg_include.packages;

    if not package_patterns and config.project.name {
        package_patterns = [config.project.name.replace("-", "_")];
    }

    candidates = sorted(
        c
        for c in proj_root.iterdir()
        if c.is_dir() and c.name not in EXCLUDED_DIRS
    );

    for pkg_glob in package_patterns {
        for candidate in candidates {
            if not fnmatch.fnmatch(candidate.name, pkg_glob) {
                continue;
            }

            specific: list[str] = list(data_map.get(candidate.name, []));
            patterns = global_patterns + specific;

            pkg_files = _collect_from_dir(candidate, proj_root, patterns, seen);
            result.extend(pkg_files);
        }
    }

    if not result {
        pkg_name = config.project.name.replace("-", "_");
        for pattern in global_patterns {
            for file_path in sorted(proj_root.glob(_make_recursive(pattern))) {
                if not file_path.is_file() {
                    continue;
                }
                if _is_excluded(file_path, proj_root) {
                    continue;
                }
                rel = str(file_path.relative_to(proj_root)).replace("\\", "/");
                if rel.split("/")[0] in FLAT_EXCLUDED_DIRS {
                    continue;
                }
                wheel_path = f"{pkg_name}/{rel}";
                if wheel_path in seen {
                    continue;
                }
                seen.add(wheel_path);
                result.append(SourceFile(wheel_path=wheel_path, source_path=file_path));
            }
        }
        init_py = f"{pkg_name}/__init__.py";
        init_jac = f"{pkg_name}/__init__.jac";
        if result and init_py not in seen and init_jac not in seen {
            seen.add(init_py);
            result.append(SourceFile(wheel_path=init_py, content=b""));
        }
    }

    return result;
}
