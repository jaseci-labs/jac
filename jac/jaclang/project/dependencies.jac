import from jaclang.project.package_scope { is_package_name }

glob PACKAGE_DEP_KEYS: tuple[str, ...] = (
         "version",
         "path",
         "git",
         "rev",
         "registry"
     ),
     PYPI_TABLE: str = "pypi",
     MIGRATE_HINT: str = "run 'jac fix dependencies' to move them";

obj ManifestError(ValueError) {}

obj PackageDep {
    has name: str,
        version: str = "*",
        path: str = "",
        git: str = "",
        rev: str = "",
        registry: str = "",
        dev: bool = False;

    def kind -> str {
        if self.path {
            return "path";
        }
        if self.git {
            return "git";
        }
        return "registry";
    }

    def to_toml -> str | dict[str, str] {
        if self.kind() == "registry" and not self.registry {
            return self.version;
        }
        out: dict[str, str] = {};
        if self.version and self.version != "*" {
            out["version"] = self.version;
        }
        for key in ("path", "git", "rev", "registry") {
            value = getattr(self, key);
            if value {
                out[key] = value;
            }
        }
        return out;
    }

    static def parse(name: str, value: any, dev: bool, section: str) -> PackageDep {
        if not is_package_name(name) {
            raise ManifestError(
                f"jac.toml [{section}]: '{name}' is not a Jac package name; Jac "
                "packages are scoped as org/name, and Python packages now live in "
                f"[{section}.{PYPI_TABLE}] ({MIGRATE_HINT})"
            );
        }
        if isinstance(value, str) {
            return PackageDep(name=name, version=value.strip() or "*", dev=dev);
        }
        if not isinstance(value, dict) {
            raise ManifestError(
                f"jac.toml [{section}]: '{name}' must be a version string or a table"
            );
        }
        unknown = [
            k
            for k in value
            if k not in PACKAGE_DEP_KEYS
        ];
        if unknown {
            raise ManifestError(
                f"jac.toml [{section}]: '{name}' has unknown key(s) "
                f"{', '.join(sorted(unknown))}; expected {', '.join(PACKAGE_DEP_KEYS)}"
            );
        }
        dep = PackageDep(
            name=name,
            version=str(value.get("version", "*")),
            path=str(value.get("path", "")),
            git=str(value.get("git", "")),
            rev=str(value.get("rev", "")),
            registry=str(value.get("registry", "")),
            dev=dev
        );
        if dep.path and dep.git {
            raise ManifestError(
                f"jac.toml [{section}]: '{name}' names both a path and a git source"
            );
        }
        if dep.rev and not dep.git {
            raise ManifestError(f"jac.toml [{section}]: '{name}' sets rev without git");
        }
        return dep;
    }
}

obj DependencyTables {
    has packages: dict[str, PackageDep] = {},
        pypi: dict[str, str] = {},
        pypi_git: dict[str, dict[str, str]] = {},
        ecosystems: dict[str, dict[str, any]] = {};
}

def _looks_like_package_dep(value: dict[str, any]) -> bool {
    if not value or any(k not in PACKAGE_DEP_KEYS for k in value) {
        return False;
    }
    git = str(value.get("git", ""));
    return bool(
        value.get("path")
            or value.get("registry")
            or "://" in git
            or git.startswith("git@")
    );
}

def split_dependency_table(
    table: dict[str, any], dev: bool, section: str
) -> DependencyTables {
    out = DependencyTables();
    stray: list[str] = [];
    for (key, value) in table.items() {
        if key == PYPI_TABLE {
            if not isinstance(value, dict) {
                raise ManifestError(
                    f"jac.toml [{section}.{PYPI_TABLE}] must be a table"
                );
            }
            for (pkg, spec) in value.items() {
                if isinstance(spec, str) {
                    out.pypi[pkg] = spec;
                } elif isinstance(spec, dict) and spec.get("git") {
                    out.pypi_git[pkg] = {str(k): str(v) for (k, v) in spec.items()};
                } else {
                    raise ManifestError(
                        f"jac.toml [{section}.{PYPI_TABLE}]: '{pkg}' must be a "
                        "version specifier or a { git = ... } table"
                    );
                }
            }
            continue;
        }
        if key == "git" and isinstance(value, dict) {
            raise ManifestError(
                f"jac.toml [{section}.git]: Python git dependencies moved to "
                f"[{section}.{PYPI_TABLE}] as name = {{ git = \"...\" }} ({MIGRATE_HINT})"
            );
        }
        if is_package_name(key) {
            out.packages[key] = PackageDep.parse(key, value, dev, section);
            continue;
        }
        if isinstance(value, dict) and not _looks_like_package_dep(value) {
            out.ecosystems[key] = value;
            continue;
        }
        stray.append(key);
    }
    if stray {
        raise ManifestError(
            f"jac.toml [{section}] lists {', '.join(sorted(stray))}, which "
            "are not Jac packages (org/name). Python packages now live in "
            f"[{section}.{PYPI_TABLE}] ({MIGRATE_HINT})"
        );
    }
    return out;
}

def migrate_dependency_table(table: dict[str, any]) -> dict[str, any] {
    out: dict[str, any] = {};
    pypi: dict[str, any] = dict(table.get(PYPI_TABLE, {}))
        if isinstance(table.get(PYPI_TABLE), dict)
        else {};
    for (key, value) in table.items() {
        if key == PYPI_TABLE {
            continue;
        }
        if key == "git" and isinstance(value, dict) {
            for (pkg, spec) in value.items() {
                pypi[pkg] = spec;
            }
            continue;
        }
        if isinstance(value, str) and not is_package_name(key) {
            pypi[key] = value;
            continue;
        }
        out[key] = value;
    }
    if pypi {
        out[PYPI_TABLE] = pypi;
    }
    return out;
}
