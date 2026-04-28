"""Implementation of the jac.toml package manifest validator."""

import re;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.publish.metadata { normalize_constraint }

# ===============================================================================
# ValidationResult
# ===============================================================================
impl ValidationResult.is_valid -> bool {
    return len(self.errors) == 0;
}

impl ValidationResult.add_error(msg: str) -> None {
    self.errors.append(msg);
}

impl ValidationResult.add_warning(msg: str) -> None {
    self.warnings.append(msg);
}

# ===============================================================================
# Internal helpers
# ===============================================================================
def _validate_pep440_version(version: str) -> str | None {
    try {
        import from packaging.version { Version }
        Version(version);
        return None;
    } except Exception {
        # packaging not installed — fall back to a conservative regex
        if re.match(
            r"^\d+(\.\d+)*"
            r"([._-]?(a|alpha|b|beta|c|rc|preview)\d*)?"
            r"(\.post\d*)?"
            r"(\.dev\d*)?$",
            version,
            re.IGNORECASE,
        ) {
            return None;
        }
        return "not a valid PEP 440 version string";
    }
}

def _validate_version_specifier(spec: str) -> str | None {
    try {
        import from packaging.specifiers { SpecifierSet }
        SpecifierSet(spec);
        return None;
    } except Exception {
        # packaging not installed — check each comma-separated clause
        for clause in spec.split(",") {
            clause = clause.strip();
            if not re.match(r"^(~=|==|!=|<=|>=|<|>)\s*\d", clause) {
                return f"'{clause}' is not a valid version specifier";
            }
        }
        return None;
    }
}

# ===============================================================================
# Main validator
# ===============================================================================
impl validate_package(
    config: JacConfig, project_root: Path | None = None
) -> ValidationResult {
    result = ValidationResult();
    root = project_root or config.project_root;

    # [package] section must exist
    if config.package is None {
        result.add_error(
            "Missing [package] section. "
            "Add [package] with at least name and version to use jac publish."
        );
        return result;
    }

    pkg = config.package;

    # ── name ────────────────────────────────────────────────────────────────
    if not pkg.name {
        result.add_error("[package] name is required.");
    } elif not re.match(r"^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?$", pkg.name) {
        result.add_error(
            f"[package] name '{pkg.name}' is not a valid package name. "
            "Use letters, digits, hyphens, underscores, and dots only."
        );
    }

    # ── version ─────────────────────────────────────────────────────────────
    if not pkg.version {
        result.add_error("[package] version is required.");
    } else {
        ver_err = _validate_pep440_version(pkg.version);
        if ver_err {
            result.add_error(f"[package] version '{pkg.version}': {ver_err}");
        }
    }

    # ── requires-python ─────────────────────────────────────────────────────
    if pkg.requires_python {
        spec_err = _validate_version_specifier(pkg.requires_python);
        if spec_err {
            result.add_error(
                f"[package] requires-python '{pkg.requires_python}': {spec_err}"
            );
        }
    } else {
        result.add_warning(
            "[package] requires-python is not set. "
            "Consider adding it (e.g. '>=3.12') so pip can reject incompatible environments."
        );
    }

    # ── readme ──────────────────────────────────────────────────────────────
    if pkg.readme and root {
        readme_path = root / pkg.readme;
        if not readme_path.exists() {
            result.add_warning(
                f"[package] readme '{pkg.readme}' not found at {readme_path}."
            );
        }
    }

    # ── authors ─────────────────────────────────────────────────────────────
    for (i, author) in enumerate(pkg.authors) {
        if not author.name and not author.email {
            result.add_warning(f"[package] authors[{i}] has neither name nor email.");
        }
    }

    # ── [dependencies] version constraints ──────────────────────────────────
    for (dep_name, raw_ver) in config.dependencies.items() {
        normalised = normalize_constraint(raw_ver);
        if normalised {
            spec_err = _validate_version_specifier(normalised);
            if spec_err {
                result.add_error(
                    f"[dependencies] {dep_name} = '{raw_ver}': "
                    f"invalid version constraint ({spec_err})."
                );
            }
        }
    }

    # ── [dev-dependencies] version constraints ───────────────────────────────
    for (dep_name, raw_ver) in config.dev_dependencies.items() {
        normalised = normalize_constraint(raw_ver);
        if normalised {
            spec_err = _validate_version_specifier(normalised);
            if spec_err {
                result.add_error(
                    f"[dev-dependencies] {dep_name} = '{raw_ver}': "
                    f"invalid version constraint ({spec_err})."
                );
            }
        }
    }

    # ── [optional-dependencies] version constraints ──────────────────────────
    for (group, deps) in config.optional_dependencies.items() {
        for (dep_name, raw_ver) in deps.items() {
            normalised = normalize_constraint(raw_ver);
            if normalised {
                spec_err = _validate_version_specifier(normalised);
                if spec_err {
                    result.add_error(
                        f"[optional-dependencies.{group}] {dep_name} = '{raw_ver}': "
                        f"invalid version constraint ({spec_err})."
                    );
                }
            }
        }
    }

    # ── [entrypoints] reference format ───────────────────────────────────────
    for (group, refs) in config.entrypoints.items() {
        for (ep_name, ref) in refs.items() {
            if not re.match(
                r"^[a-zA-Z_][a-zA-Z0-9_.]*:[a-zA-Z_][a-zA-Z0-9_.]*$", ref
            ) {
                result.add_error(
                    f"[entrypoints.{group}] {ep_name} = '{ref}': "
                    "must be in 'module.path:attribute' format."
                );
            }
        }
    }

    return result;
}
