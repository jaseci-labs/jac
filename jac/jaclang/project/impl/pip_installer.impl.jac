"""Implementation of pip-style editable installer for Jac projects."""

import subprocess;
import sys;
import from pathlib { Path }
import from jaclang.project.dependencies { DependencyInstaller }

# ===============================================================================
# Helper Functions
# ===============================================================================
"""Format a dependency specification for pip."""
def _format_dep_spec(name: str, version: str, quoted: bool = False) -> str {
    if not version or version == ">=0.0.0" {
        spec = name;
    } elif version.startswith(("=", ">", "<", "~", "!")) {
        spec = f"{name}{version}";
    } else {
        spec = f"{name}=={version}";
    }
    return f'"{spec}"' if quoted else spec;
}

# ===============================================================================
# JacPipInstaller Implementation
# ===============================================================================
impl JacPipInstaller.postinit -> None {
    if not self.project_path.is_absolute() {
        self.project_path = self.project_path.resolve();
    }
}

impl JacPipInstaller.install_editable(
    deps: bool = True, include_dev: bool = False, extras: list[str] = []
) -> bool {
    # If only installing dev/optional dependencies (not full editable install)
    if not deps and (include_dev or extras) {
        return DependencyInstaller(
            config=self.config, verbose=self.verbose, stream_output=True
        ).install_all(
            deps=False, include_dev=include_dev, extras=extras
        );
    }
    # Full editable install (with optional dev/extras)
    return self._setup_editable_install();
}

impl JacPipInstaller._setup_editable_install -> bool {
    pyproject_path = self.project_path / "pyproject.toml";
    if self.verbose {
        print("  Generating pyproject.toml from jac.toml");
    }
    with open(pyproject_path, "w") as f {
        f.write(generate_pyproject_from_jac_toml(self.config));
    }
    try {
        (returncode, _, _) = DependencyInstaller(
            config=self.config, verbose=self.verbose, stream_output=True
        )._run_pip(
            ["install", "-e", "."],
            cwd=self.project_path,
            verbose=self.verbose,
            stream_output=True
        );

        if returncode == 0 {
            jac_entry_points = self.config._raw_data.get("project", {}).get(
                "entry-points", {}
            ).get(
                "jac", {}
            );
            if jac_entry_points {
                print(f"Registered {len(jac_entry_points)} Jac plugin entry point(s)");
            }
            return True;
        }

        print("Editable install failed", file=sys.stderr);
        return False;
    } finally {
        if pyproject_path.exists() {
            try {
                pyproject_path.unlink();
                if self.verbose {
                    print("  Cleaned up generated pyproject.toml");
                }
            } except Exception as e {
                if self.verbose {
                    print(
                        f"  Warning: Failed to remove pyproject.toml: {e}",
                        file=sys.stderr
                    );
                }
            }
        }
    }
}

# ===============================================================================
# Standalone Functions
# ===============================================================================
"""Generate a minimal pyproject.toml from jac.toml for pip editable install."""
impl generate_pyproject_from_jac_toml(config: "JacConfig") -> str {
    lines: list[str] = [
        "[build-system]",
        'requires = ["setuptools>=61.0"]',
        'build-backend = "setuptools.build_meta"',
        "",
        "[project]",
        f'name = "{config.project.name.replace('\\', '\\\\').replace('"', '\\"')}"',
        f'version = "{config.project.version.replace('\\', '\\\\').replace('"', '\\"')}"'
    ];
    if config.project.description {
        lines.append(
            f'description = "{config.project.description.replace('"', '\\"')}"'
        );
    }
    if config.project.readme {
        lines.append(f'readme = "{config.project.readme.replace('"', '\\"')}"');
    }
    if config.project.license {
        lines.append(f'license = "{config.project.license.replace('"', '\\"')}"');
    }
    lines.append('requires-python = ">=3.11"');
    # Dependencies
    if config.dependencies {
        deps = [
            f'    {_format_dep_spec(n, v, quoted=True)}'
            for (n, v) in config.dependencies.items()
        ];
        lines.extend(["dependencies = [", ",\n".join(deps), "]"]);
    }
    lines.append("");
    # Optional dependencies
    if config.dev_dependencies or config.optional_dependencies {
        lines.append("[project.optional-dependencies]");
        if config.dev_dependencies {
            dev = [
                _format_dep_spec(n, v, quoted=True)
                for (n, v) in config.dev_dependencies.items()
            ];
            lines.append(f'dev = [{", ".join(dev)}]');
        }
        for (group, deps) in config.optional_dependencies.items() {
            group_deps = [
                _format_dep_spec(n, v, quoted=True) for (n, v) in deps.items()
            ];
            lines.append(f'{group} = [{", ".join(group_deps)}]');
        }
        lines.append("");
    }
    # Entry points
    jac_entry_points = config._raw_data.get("project", {}).get("entry-points", {}).get(
        "jac", {}
    );
    if jac_entry_points {
        lines.append('[project.entry-points."jac"]');
        for (ep_name, ep_value) in jac_entry_points.items() {
            escaped_ep_value = ep_value.replace("\\", "\\\\").replace('"', '\\"');
            lines.append(f'{ep_name} = "{escaped_ep_value}"');
        }
        lines.append("");
    }
    # Setuptools
    pkg_name = config.project.name.replace("-", "_");
    lines.extend(
        [
            "[tool.setuptools.packages.find]",
            f'include = ["{pkg_name}*"]',
            "",
            "[tool.setuptools.package-data]",
            '"*" = ["*.jac", "*.impl/*.jac", "*.cl/*.jac"]',
            ""
        ]
    );
    return "\n".join(lines);
}
