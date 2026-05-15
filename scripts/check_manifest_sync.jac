"""Verify that jac.toml and pyproject.toml agree on the fields that ship to PyPI.

jac.toml is the planned source of truth once publish-release.yml uses
`jac bundle` for plugin packages. Until pyproject.toml is removed from
plugin directories, the two files must stay in sync so we never silently
ship different metadata depending on which builder ran.

Fields checked (per plugin package, never jaclang itself):
    [project] name, version, description, requires-python
    [project.urls]            <-> [project.urls]            (case-insensitive keys)
    [dependencies]            <-> [project] dependencies
    [dev-dependencies]        <-> [project.optional-dependencies].dev
    [optional-dependencies.X] <-> [project.optional-dependencies].X

Dependency specs are normalized for comparison:
    - package names: PEP 503 (lowercase, _ -> -)
    - version ops: whitespace-stripped, separator order preserved-then-sorted

Run:  jac run scripts/check_manifest_sync.jac
Exit: 0 if all packages agree, 1 if any drift is found.
"""
import from __future__ { annotations }
import re;
import sys;
import from pathlib { Path }
import tomlkit;

glob PLUGIN_DIRS: list[str] = [
         "jac-byllm",
         "jac-client",
         "jac-mcp",
         "jac-scale",
         "jac-super",
         "jaseci-package",

     ];

"""PEP 503 normalization: lowercase, runs of [-_.] become single -."""
def normalize_name(name: str) -> str {
    return re.sub(r"[-_.]+", "-", name).lower();
}

"""Convert (name, version) from jac.toml shape into pyproject-style spec.

jac.toml stores deps as `name = ">=1.0"` (table). pyproject stores them
as `"name>=1.0"` (string list). Output canonical form: normalized name +
sorted version constraints with whitespace removed.
"""
def normalize_spec(name: str, version: str) -> str {
    norm_name = normalize_name(name);
    v = version.strip();
    if (v in ("", "*")) {
        return norm_name;
    }
    if not re.match(r"^[<>=!~]", v) {
        v = f"=={v}";
    }
    parts = sorted(
        [
            p.strip()
            for p in v.split(",")
            if p.strip()
        ]
    );
    return f"{norm_name}{','.join(parts)}";
}

"""Canonicalize a pyproject-style dep string for comparison."""
def parse_pyproject_spec(spec: str) -> str {
    s = spec.strip();
    # Strip env markers (everything after ';') -- jac.toml has no marker syntax.
    if ";" in s {
        s = s.split(";")[0].strip();
    }
    m = re.match(r"^([A-Za-z0-9_.\-]+)(\[.*\])?(.*)$", s);
    if not m {
        return s;
    }
    (name, extras, rest) = (m.group(1), m.group(2) or "", m.group(3) or "");
    norm = normalize_name(name);
    rest = rest.strip();
    if (not rest) {
        return f"{norm}{extras}";
    }
    parts = sorted(
        [
            p.strip()
            for p in rest.split(",")
            if p.strip()
        ]
    );
    return f"{norm}{extras}{','.join(parts)}";
}

def jac_deps_to_specs(deps: dict) -> set[str] {
    return {normalize_spec(name, str(version)) for (name, version) in deps.items()};
}

def py_deps_to_specs(deps: list) -> set[str] {
    return {parse_pyproject_spec(str(s)) for s in deps};
}

def compare_section(label: str, jac_specs: set[str], py_specs: set[str]) -> list[str] {
    if (jac_specs == py_specs) {
        return [];
    }
    errors: list[str] = [];
    only_jac = jac_specs - py_specs;
    only_py = py_specs - jac_specs;
    if only_jac {
        errors.append(f"  {label}: only in jac.toml -> {sorted(only_jac)}");
    }
    if only_py {
        errors.append(f"  {label}: only in pyproject.toml -> {sorted(only_py)}");
    }
    return errors;
}

def check_package(repo_root: Path, pkg_dir: str) -> list[str] {
    jac_toml_path = repo_root / pkg_dir / "jac.toml";
    pyproject_path = repo_root / pkg_dir / "pyproject.toml";
    if not jac_toml_path.exists() or not pyproject_path.exists() {
        return [];  # one-sided; not our concern here
    }
    jac_data = tomlkit.loads(jac_toml_path.read_text());
    py_data = tomlkit.loads(pyproject_path.read_text());

    errors: list[str] = [];

    jac_project = jac_data.get("project", {});
    py_project = py_data.get("project", {});
    for field in ("name", "version", "description", "requires-python") {
        jv = jac_project.get(field);
        pv = py_project.get(field);
        if (jv is not None) and (pv is not None) and (str(jv) != str(pv)) {
            errors.append(f"  [project].{field}: jac={jv!r} pyproject={pv!r}");
        }
    }

    # URL keys are case-insensitive per PEP 621.
    jac_urls = {k.lower(): str(v) for (k, v) in jac_project.get("urls", {}).items()};
    py_urls = {k.lower(): str(v) for (k, v) in py_project.get("urls", {}).items()};
    for key in sorted(set(jac_urls.keys()) | set(py_urls.keys())) {
        jv = jac_urls.get(key);
        pv = py_urls.get(key);
        if (jv != pv) {
            errors.append(f"  [project.urls].{key}: jac={jv!r} pyproject={pv!r}");
        }
    }

    jac_deps = jac_deps_to_specs(jac_data.get("dependencies", {}));
    py_deps = py_deps_to_specs(py_project.get("dependencies", []));
    errors.extend(compare_section("[dependencies]", jac_deps, py_deps));

    jac_dev = jac_deps_to_specs(jac_data.get("dev-dependencies", {}));
    py_opt = py_project.get("optional-dependencies", {});
    py_dev = py_deps_to_specs(py_opt.get("dev", []));
    errors.extend(compare_section("[dev-dependencies]", jac_dev, py_dev));

    jac_opt_table = jac_data.get("optional-dependencies", {});
    jac_extras = set(jac_opt_table.keys());
    py_extras = set(py_opt.keys()) - {"dev"};
    for extra in sorted(jac_extras | py_extras) {
        jac_extra = jac_deps_to_specs(jac_opt_table.get(extra, {}));
        py_extra = py_deps_to_specs(py_opt.get(extra, []));
        errors.extend(
            compare_section(f"[optional-dependencies.{extra}]", jac_extra, py_extra)
        );
    }

    return errors;
}

def main -> int {
    repo_root = Path(__file__).resolve().parent.parent;
    all_failed = False;
    for pkg in PLUGIN_DIRS {
        errs = check_package(repo_root, pkg);
        if errs {
            all_failed = True;
            print(f"\n{pkg}: jac.toml and pyproject.toml disagree");
            for e in errs {
                print(e);
            }
        }
    }
    if all_failed {
        print("\nFix: update jac.toml to match pyproject.toml (or vice versa).");
        print("Both files must agree until pyproject.toml is removed from plugins.");
        return 1;
    }
    print("All plugin manifests agree.");
    return 0;
}

with entry:__main__ {
    sys.exit(main());
}
