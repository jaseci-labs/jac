"""Per-app npm dependencies are unioned across the workspace's client apps.
Two apps that pin the same package at different versions keep the first
declaration, and the conflict is reported once per package so the loser is
never silently overridden."""

import io;
import from contextlib { redirect_stderr }
import from jaclang.project.config { JacConfig }
import from jaclang.client.npm_provider { app_npm_deps }

glob _TOML: str = (
         '[project]\nname = "acme"\ndefault-app = "web"\n\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n\n[apps.admin]\nkind = "web-app"\nentry-point = "admin.main"\n\n[apps.tool]\nkind = "cli"\nentry-point = "tool.main"\n\n[dependencies.npm]\nreact = "^19"\n\n[apps.web.dependencies.npm]\nlucide-react = "^0.5"\nzustand = "^4"\n\n[apps.web.dependencies.npm.dev]\nvitest = "^2"\n\n[apps.admin.dependencies.npm]\nlucide-react = "^0.6"\nrecharts = "^3"\n\n[apps.admin.dependencies.npm.dev]\nvitest = "^2"\n\n[apps.tool.dependencies.npm]\nlucide-react = "^0.9"\n'
     );

def _resolve(toml: str) -> tuple[list[any], str] {
    buf = io.StringIO();
    with redirect_stderr(buf) {
        deps = app_npm_deps(JacConfig.from_toml_str(toml));
    }
    return (deps, buf.getvalue());
}

test "the first app to pin a package wins and every conflict is reported once" {
    (deps, err) = _resolve(_TOML);
    by_name = {(name, dev): (version, origin) for (name, version, origin, dev) in deps};
    assert by_name[("lucide-react", False)] == ("^0.5", "app:web") , by_name;
    assert by_name[("recharts", False)] == ("^3", "app:admin") , by_name;
    assert by_name[("zustand", False)] == ("^4", "app:web") , by_name;
    assert by_name[("vitest", True)] == ("^2", "app:web") , by_name;
    assert ("react", False) not in by_name , "base deps are not per-app deps";
    assert err.count("lucide-react") == 1 , err;
    assert "'^0.5'" in err and "'^0.6'" in err , err;
    assert "app:web" in err and "app:admin" in err , err;
    assert "vitest" not in err , "an agreeing pin is not a conflict: " + err;
    assert "recharts" not in err , err;
    assert "^0.9" not in err , "a cli app declares no client deps: " + err;
}

test "agreeing pins and disjoint apps are silent" {
    quiet = _TOML.replace('lucide-react = "^0.6"', 'lucide-react = "^0.5"');
    (deps, err) = _resolve(quiet);
    assert err == "" , err;
    names = [name for (name, _, _, _) in deps];
    assert names.count("lucide-react") == 1 , names;
}

"""A project written for neojac lists a space's packages as an npm tree,
`[npm.<tree>]`, whose `dependencies` and `devDependencies` are the tree's
package.json. The tree a client app's space names with `[spaces.<space>] npm`
joins that app's packages; a project with one tree gives it to every client app."""
test "an npm tree's packages are a client app's packages" {
    toml = (
        '[project]\nname = "acme"\ndefault-app = "web"\n\n'
        '[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n\n'
        '[apps.tool]\nkind = "cli"\nentry-point = "tool.main"\n\n'
        '[npm.web]\nname = "acme"\nprivate = true\n\n'
        '[npm.web.dependencies]\nmermaid = "^11"\nreact = "^19.1.0"\n\n'
        '[npm.web.devDependencies]\n"@tailwindcss/vite" = "^4.1.17"\n'
    );
    (deps, err) = _resolve(toml);
    by_name = {(name, dev): (version, origin) for (name, version, origin, dev) in deps};
    assert by_name[("mermaid", False)] == ("^11", "npm.web") , by_name;
    assert by_name[("@tailwindcss/vite", True)] == ("^4.1.17", "npm.web") , by_name;
    assert err == "" , err;
}
