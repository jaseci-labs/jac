"""Tests for `jac fix access`: the migration to declared exposure.

Plain top-level defs in a serving app's entry (and the plain defs that entry
imports from project modules) plus every plain walker reachable from a
serving app become `:protect`; `_`-prefixed names, `:pub` declarations, and
JSX components are left alone. Dry runs write nothing and the migration is
idempotent."""

import os;
import tempfile;
import from jaclang.cli.commands.fix { fix, _access_plan }

glob TOML: str = '[project]\nname = "fixture"\ndefault-app = "web"\n\n[apps.web]\nkind = "web-app"\nentry-point = "main"\n',
     MAIN: str = (
         'import from helpers { shout, quiet }\n'
         'import from tools.audit { AuditRun }\n\n'
         'def:pub public_ping -> int {\n    return 1;\n}\n\n'
         'def plain_endpoint(x: int) -> int {\n    return x;\n}\n\n'
         'async def plain_async(x: int) -> int {\n    return x;\n}\n\n'
         'def _helper(x: int) -> int {\n    return x;\n}\n\n'
         'walker PlainWalker {\n    can go with Root entry {\n        report 1;\n    }\n}\n\n'
         'walker:pub PublicWalker {\n    can go with Root entry {\n        report 2;\n    }\n}\n\n'
         'def:pub app -> JsxElement {\n    return <div>{shout("x")}</div>;\n}\n'
     ),
     HELPERS: str = (
         'def shout(s: str) -> str {\n    return s.upper();\n}\n\n'
         'def quiet(s: str) -> str {\n    return s.lower();\n}\n\n'
         'def untouched(s: str) -> str {\n    return s;\n}\n'
     ),
     AUDIT: str = (
         'walker AuditRun {\n    can go with Root entry {\n        report 3;\n    }\n}\n\n'
         'walker _Hook {\n    can go with Root entry {\n        report 4;\n    }\n}\n\n'
         'walker:priv LegacyPriv {\n    can go with Root entry {\n        report 5;\n    }\n}\n\n'
         'def:priv legacy_priv_fn(x: int) -> int {\n    return x;\n}\n'
     );

def _write_project(tmpdir: str) -> str {
    with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
        f.write(TOML);
    }
    with open(os.path.join(tmpdir, "main.jac"), "w") as f {
        f.write(MAIN);
    }
    with open(os.path.join(tmpdir, "helpers.jac"), "w") as f {
        f.write(HELPERS);
    }
    os.makedirs(os.path.join(tmpdir, "tools"), exist_ok=True);
    with open(os.path.join(tmpdir, "tools", "audit.jac"), "w") as f {
        f.write(AUDIT);
    }
    return tmpdir;
}

def _read(path: str) -> str {
    with open(path) as f {
        return f.read();
    }
}

test "fix access marks entry defs, imported defs and reachable walkers :protect" {
    with tempfile.TemporaryDirectory() as tmpdir {
        proj = _write_project(tmpdir);
        rc = fix("access", [proj]);
        assert rc == 0;
        main = _read(os.path.join(proj, "main.jac"));
        assert "def:protect plain_endpoint(" in main , main;
        assert "async def:protect plain_async(" in main , main;
        assert "walker:protect PlainWalker" in main , main;
        assert "def:pub public_ping" in main , "pub stays pub";
        assert "walker:pub PublicWalker" in main , "pub walkers stay pub";
        assert "def _helper(" in main , "underscore helpers are left alone";
        assert "def:pub app -> JsxElement" in main , "components are left alone";
        helpers = _read(os.path.join(proj, "helpers.jac"));
        assert "def:protect shout(" in helpers , helpers;
        assert "def:protect quiet(" in helpers , helpers;
        assert "def untouched(" in helpers , "unimported helpers stay private";
        audit = _read(os.path.join(proj, "tools", "audit.jac"));
        assert "walker:protect AuditRun" in audit , audit;
        assert "walker _Hook" in audit , "underscore walkers are middleware, left alone";
        assert "walker:priv LegacyPriv" in audit , ":priv walkers are never rewritten";
        assert "def:priv legacy_priv_fn(" in audit , ":priv defs are never rewritten";
    }
}

test "fix access reports :priv declarations that used to be served" {
    with tempfile.TemporaryDirectory() as tmpdir {
        proj = _write_project(tmpdir);
        (plan, notes) = _access_plan(proj);
        names = {rw.name for rw in plan};
        assert "LegacyPriv" not in names and "legacy_priv_fn" not in names , names;
        priv_notes = [
            n
            for n in notes
            if ":priv" in n
        ];
        assert any(
            "LegacyPriv" in n and "now private" in n for n in priv_notes
        ) , notes;
        assert any("legacy_priv_fn" in n for n in priv_notes) , notes;
    }
}

test "fix access --dry-run writes nothing and a second run is a no-op" {
    with tempfile.TemporaryDirectory() as tmpdir {
        proj = _write_project(tmpdir);
        before = _read(os.path.join(proj, "main.jac"));
        assert fix("access", [proj], dry_run=True) == 0;
        assert _read(os.path.join(proj, "main.jac")) == before;
        assert fix("access", [proj]) == 0;
        after = _read(os.path.join(proj, "main.jac"));
        assert fix("access", [proj]) == 0;
        assert _read(os.path.join(proj, "main.jac")) == after , "idempotent";
        assert after.count(":protect") == 3 , after;
    }
}

test "fix access without a serving app changes nothing" {
    with tempfile.TemporaryDirectory() as tmpdir {
        with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
            f.write('[project]\nname = "tool"\nkind = "cli"\nentry-point = "main"\n');
        }
        with open(os.path.join(tmpdir, "main.jac"), "w") as f {
            f.write('def helper -> int {\n    return 1;\n}\n');
        }
        assert fix("access", [tmpdir]) == 0;
        assert _read(os.path.join(tmpdir, "main.jac"))
            == 'def helper -> int {\n    return 1;\n}\n';
    }
}

test "fix access follows recursive includes in the entry namespace" {
    with tempfile.TemporaryDirectory() as tmp {
        with open(os.path.join(tmp, "jac.toml"), "w") as f {
            f.write(TOML);
        }
        files = {
            "main.jac": "include utils;\n",
            "utils.jac": (
                "include nested;\n"
                + "import from helpers { used }\n"
                + "def included -> int { return used(); }\n"
                + "walker IncludedWalker {}\n"
                + "def:priv secret -> int { return 0; }\n"
            ),
            "nested.jac": "include utils;\ndef nested -> int { return 2; }\n",
            "helpers.jac": (
                "def used -> int { return 1; }\n"
                + "def untouched -> int { return 0; }\n"
            )
        };
        for (name, source) in files.items() {
            with open(os.path.join(tmp, name), "w") as f {
                f.write(source);
            }
        }
        (plan, notes) = _access_plan(tmp);
        assert {rw.name for rw in plan}
            == {"included", "IncludedWalker", "nested", "used"} , plan;
        assert len(plan) == 4 , "cycles must not duplicate rewrites";
        assert any("secret" in note for note in notes) , notes;
        assert fix("access", [tmp], dry_run=True) == 0;
        assert _read(os.path.join(tmp, "utils.jac")) == files["utils.jac"];
        assert fix("access", [tmp]) == 0;
        assert "def:protect included" in _read(os.path.join(tmp, "utils.jac"));
        assert "def:protect nested" in _read(os.path.join(tmp, "nested.jac"));
        assert "def untouched" in _read(os.path.join(tmp, "helpers.jac"));
        assert _access_plan(tmp)[0] == [];
    }
}
