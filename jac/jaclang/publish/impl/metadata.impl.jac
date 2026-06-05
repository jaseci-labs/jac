"""Implementation of the METADATA file generator."""

import from pathlib { Path }
import from jaclang.project.config { JacConfig, PersonConfig }

impl normalize_package_name(name: str) -> str {
    result: list[str] = [];
    prev_sep: bool = False;
    for ch in name {
        if ch in "-_." {
            if not prev_sep {
                result.append("-");
            }
            prev_sep = True;
        } else {
            result.append(ch);
            prev_sep = False;
        }
    }
    return "".join(result).lower();
}

def build_person_header(persons: list[PersonConfig]) -> str {
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

impl normalize_constraint(raw: str) -> str {
    raw = raw.strip();

    if not raw or raw in ("*", "latest") {
        return "";
    }

    # npm caret: ^MAJOR[.MINOR[.PATCH]]
    if raw.startswith("^") {
        ver_str = raw[1:];
        parts = ver_str.split(".");
        try {
            major = int(parts[0]);
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
            major = int(parts[0]);
            minor = int(parts[1]) if len(parts) > 1 else 0;
        } except ValueError {
            return raw;
        }
        padded = ".".join(parts + ["0"] * (3 - len(parts)));
        return f">={padded},<{major}.{minor + 1}.0";
    }

    if raw[0] in (">", "<", "!", "~", "=") {
        return raw;
    }

    if raw[0].isdigit() {
        return f"=={raw}";
    }

    return raw;
}

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

def readme_content_type(ext: str) -> str {
    if ext == ".md" {
        return "text/markdown";
    } elif ext == ".rst" {
        return "text/x-rst";
    } else {
        return "text/plain";
    }
}

impl generate_metadata(config: JacConfig, project_root: Path | None = None) -> str {
    if not config.project.name {
        raise ValueError(
            "Cannot generate METADATA: [project] name is missing in jac.toml."
        );
    }

    pkg = config.project;
    proj_root = project_root or config.project_root;
    lines: list[str] = [];

    def h(hdr: str, value: str) {
        if value {
            lines.append(f"{hdr}: {value}");
        }
    }

    h("Metadata-Version", METADATA_VERSION);
    h("Name", normalize_package_name(pkg.name));
    h("Version", pkg.version);
    h("Summary", pkg.description);

    h("Author-email", build_person_header(pkg.authors));
    h("Maintainer-email", build_person_header(pkg.maintainers));
    h("License-Expression", pkg.license);
    h("Keywords", ",".join(pkg.keywords));

    for classifier in pkg.classifiers {
        h("Classifier", classifier);
    }

    h("Requires-Python", pkg.requires_python);

    for (label, url) in pkg.urls.items() {
        lines.append(f"Project-URL: {label.capitalize()}, {url}");
    }

    for (dep_name, raw_ver) in config.dependencies.items() {
        h("Requires-Dist", build_requires_dist(dep_name, raw_ver));
    }

    for (group, deps) in config.optional_dependencies.items() {
        h("Provides-Extra", group);
        for (dep_name, raw_ver) in deps.items() {
            h("Requires-Dist", build_requires_dist(dep_name, raw_ver, extra=group));
        }
    }

    if config.dev_dependencies {
        h("Provides-Extra", "dev");
        for (dep_name, raw_ver) in config.dev_dependencies.items() {
            h("Requires-Dist", build_requires_dist(dep_name, raw_ver, extra="dev"));
        }
    }

    if pkg.readme and proj_root {
        readme_path = proj_root / pkg.readme;
        if readme_path.exists() {
            h(
                "Description-Content-Type",
                readme_content_type(readme_path.suffix.lower())
            );
        }
    }

    lines.append("");

    if pkg.readme and proj_root {
        readme_path = proj_root / pkg.readme;
        if readme_path.exists() {
            lines.append(readme_path.read_text(encoding="utf-8"));
        }
    }

    return "\n".join(lines);
}

def _toml_str(s: str) -> str {
    return (
        s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace(
            "\r", "\\r"
        ).replace(
            "\t", "\\t"
        )
    );
}

impl generate_pyproject_toml(config: JacConfig) -> str {
    if not config.project.name {
        raise ValueError(
            "Cannot generate pyproject.toml: [project] name is missing in jac.toml."
        );
    }

    pkg = config.project;
    lines: list[str] = [
        "[build-system]",
        'requires = ["jaclang"]',
        'build-backend = "_jac_build"',
        'backend-path = ["."]',
        "",
        "[project]",
        f'name = "{normalize_package_name(pkg.name)}"',
        f'version = "{pkg.version}"',

    ];

    if pkg.description {
        lines.append(f'description = "{_toml_str(pkg.description)}"');
    }
    if pkg.requires_python {
        lines.append(f'requires-python = "{pkg.requires_python}"');
    }
    if pkg.license {
        lines.append(f'license = {{text = "{_toml_str(pkg.license)}"}}');
    }
    if pkg.keywords {
        kw_items = ", ".join(f'"{_toml_str(k)}"' for k in pkg.keywords);
        lines.append(f'keywords = [{kw_items}]');
    }
    if pkg.classifiers {
        lines.append("classifiers = [");
        for cls in pkg.classifiers {
            lines.append(f'    "{_toml_str(cls)}",');
        }
        lines.append("]");
    }
    if pkg.authors {
        lines.append("authors = [");
        for p in pkg.authors {
            if p.name and p.email {
                lines.append(
                    f'    {{name = "{_toml_str(p.name)}", email = "{_toml_str(
                        p.email
                    )}"}},'
                );
            } elif p.name {
                lines.append(f'    {{name = "{_toml_str(p.name)}"}},');
            } elif p.email {
                lines.append(f'    {{email = "{_toml_str(p.email)}"}},');
            }
        }
        lines.append("]");
    }
    if config.dependencies {
        lines.append("dependencies = [");
        for (dep_name, raw_ver) in config.dependencies.items() {
            spec = normalize_constraint(raw_ver);
            norm_name = normalize_package_name(dep_name);
            dep_str = f"{norm_name}{spec}" if spec else norm_name;
            lines.append(f'    "{dep_str}",');
        }
        lines.append("]");
    }

    all_extras: dict[str, dict[str, str]] = dict(config.optional_dependencies);
    if config.dev_dependencies {
        all_extras["dev"] = config.dev_dependencies;
    }
    if all_extras {
        lines.append("");
        lines.append("[project.optional-dependencies]");
        for (group, deps) in all_extras.items() {
            lines.append(f"{group} = [");
            for (dep_name, raw_ver) in deps.items() {
                lines.append(f'    "{build_requires_dist(dep_name, raw_ver)}",');
            }
            lines.append("]");
        }
    }

    return "\n".join(lines) + "\n";
}
