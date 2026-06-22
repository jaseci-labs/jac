"""Fail CI if a plugin's jac.toml and pyproject.toml disagree on what ships to PyPI.

Transitional guard while both files coexist. Once pyproject.toml is removed
from plugin directories, delete this script and its contribution-checks step.

Checks: [project] name/version/description/requires-python, [project.urls]
(case-insensitive keys), runtime deps, dev deps, and named optional-extras.
"""
import from __future__ { annotations }
import sys;
import from pathlib { Path }
import tomllib;
import from packaging.requirements { Requirement }
import from packaging.utils { canonicalize_name }

glob PLUGIN_DIRS: list[str] = [
         "jac-byllm",
         "jac-mcp",
         "jac-scale",
         "jaseci-package",

     ];

"""Canonicalize a PEP-508 dep string: pep503-name + sorted-extras + sorted-specs.

Env markers (anything after `;`) are stripped — jac.toml has no marker syntax.
"""
def canon(req_str: str) -> str {
    r = Requirement(req_str.split(";")[0].strip());
    name = canonicalize_name(r.name);
    extras = f"[{','.join(sorted(r.extras))}]" if r.extras else "";
    specs = ",".join(sorted(str(s) for s in r.specifier));
    return f"{name}{extras}{specs}";
}

"""Convert jac.toml's `name = "version"` dict to PEP-508 strings, then canonicalize."""
def jac_specs(deps: dict) -> set[str] {
    out: set[str] = set();
    for (raw_name, version) in deps.items() {
        n = str(raw_name);
        v = str(version).strip();
        if v in ("", "*") {
            out.add(canon(n));
        } elif v[0] in "<>=!~" {
            out.add(canon(f"{n}{v}"));
        } else {
            out.add(canon(f"{n}=={v}"));
        }
    }
    return out;
}

def py_specs(deps: list) -> set[str] {
    return {canon(str(s)) for s in deps};
}

def diff_sets(label: str, jac: set[str], py: set[str]) -> list[str] {
    if jac == py {
        return [];
    }
    out: list[str] = [];
    if jac - py {
        out.append(f"  {label}: only in jac.toml -> {sorted(jac - py)}");
    }
    if py - jac {
        out.append(f"  {label}: only in pyproject.toml -> {sorted(py - jac)}");
    }
    return out;
}

def check_package(repo_root: Path, pkg_dir: str) -> list[str] {
    jt_path = repo_root / pkg_dir / "jac.toml";
    py_path = repo_root / pkg_dir / "pyproject.toml";
    if not jt_path.exists() or not py_path.exists() {
        return [];
    }
    jt = tomllib.loads(jt_path.read_text());
    py = tomllib.loads(py_path.read_text());
    jp = jt.get("project", {});
    pp = py.get("project", {});

    errors: list[str] = [];

    for field in ("name", "version", "description", "requires-python") {
        (a, b) = (jp.get(field), pp.get(field));
        if a is not None and b is not None and str(a) != str(b) {
            errors.append(f"  [project].{field}: jac={a!r} pyproject={b!r}");
        }
    }

    # PEP 621: project.urls keys are case-insensitive; compare lowercased.
    ju = {k.lower(): str(v) for (k, v) in jp.get("urls", {}).items()};
    pu = {k.lower(): str(v) for (k, v) in pp.get("urls", {}).items()};
    for key in sorted(set(ju) | set(pu)) {
        if ju.get(key) != pu.get(key) {
            errors.append(
                f"  [project.urls].{key}: jac={ju.get(key)!r} pyproject={pu.get(key)!r}"
            );
        }
    }

    errors.extend(
        diff_sets(
            "[dependencies]",
            jac_specs(jt.get("dependencies", {})),
            py_specs(pp.get("dependencies", [])),
        )
    );

    py_opt = pp.get("optional-dependencies", {});
    errors.extend(
        diff_sets(
            "[dev-dependencies]",
            jac_specs(jt.get("dev-dependencies", {})),
            py_specs(py_opt.get("dev", [])),
        )
    );

    jt_opt = jt.get("optional-dependencies", {});
    for extra in sorted(set(jt_opt) | (set(py_opt) - {"dev"})) {
        errors.extend(
            diff_sets(
                f"[optional-dependencies.{extra}]",
                jac_specs(jt_opt.get(extra, {})),
                py_specs(py_opt.get(extra, [])),
            )
        );
    }

    return errors;
}

def main -> int {
    repo_root = Path(__file__).resolve().parent.parent;
    drifted = False;
    for pkg in PLUGIN_DIRS {
        errs = check_package(repo_root, pkg);
        if errs {
            drifted = True;
            print(f"\n{pkg}: jac.toml and pyproject.toml disagree");
            for e in errs {
                print(e);
            }
        }
    }
    if drifted {
        print("\nFix: align jac.toml with pyproject.toml. Both must agree until");
        print("pyproject.toml is removed from plugin directories.");
        return 1;
    }
    print("All plugin manifests agree.");
    return 0;
}

with entry:__main__ {
    sys.exit(main());
}
