"""Keep Python record interoperability behind its explicit adapter."""

import re;
import subprocess;
import from pathlib { Path }

test "only the interoperability adapter directly imports Python record helpers" {
    repo = Path(__file__).resolve().parents[3];
    paths = subprocess.check_output(
        ["git", "-C", str(repo), "ls-files", "--", "*.jac"], text=True
    ).splitlines();
    forbidden: list[str] = [];
    for name in paths {
        if "/vendor/" in name or name == "jac/jaclang/runtime/object_interop.jac" {
            continue;
        }
        source = (repo / name).read_text();
        if re.search(r"(?m)^\s*import\s+(?:from\s+)?dataclasses\b", source) {
            forbidden.append(name);
        }
    }
    assert not forbidden , str(forbidden);
}


test "explicit object construction decorators stay inside runtime implementation" {
    repo = Path(__file__).resolve().parents[3];
    paths = subprocess.check_output(
        ["git", "-C", str(repo), "ls-files", "--", "*.jac"], text=True
    ).splitlines();
    allowed = {
        "jac/jaclang/runtime/archetype.jac",
        "jac/tests/runtimelib/test_object_model.jac"
    };
    forbidden: list[str] = [];
    for name in paths {
        if "/vendor/" in name or name in allowed {
            continue;
        }
        if re.search(r"(?m)^\s*@make_object\b", (repo / name).read_text()) {
            forbidden.append(name);
        }
    }
    assert not forbidden , str(forbidden);
}
