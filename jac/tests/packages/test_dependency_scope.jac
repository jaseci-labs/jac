import os;
import tempfile;
import from unittest.mock { patch }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.compilation_context { cache_scope }
import from jaclang.compiler.driver.jir { compute_module_key }
import from jaclang.project.package_scope {
    import_prefix,
    is_dependency_module,
    is_package_name,
    package_root_of
}
import from tests.support { cache_env }

def _write(path: str, body: str) {
    os.makedirs(os.path.dirname(path), exist_ok=True);
    with open(path, "w") as fh {
        fh.write(body);
    }
}

def _tree -> dict[str, str] {
    tmp = os.path.realpath(tempfile.mkdtemp());
    paths = {
        "tmp": tmp,
        "app": os.path.join(tmp, "app"),
        "other": os.path.join(tmp, "other"),
        "lib": os.path.join(tmp, "lib")
    };
    _write(os.path.join(paths["app"], "jac.toml"), "[project]\nname = \"app\"\n");
    _write(os.path.join(paths["other"], "jac.toml"), "[project]\nname = \"other\"\n");
    _write(os.path.join(paths["lib"], "jac.toml"), "[project]\nname = \"acme/lib\"\n");
    paths["util"] = os.path.join(paths["lib"], "util.jac");
    _write(paths["util"], "def one -> int {\n    return 1;\n}\n");
    paths["main"] = os.path.join(paths["app"], "main.jac");
    _write(paths["main"], "with entry {\n    print(1);\n}\n");
    return paths;
}

def _key(path: str, options: CompileOptions) -> str {
    with cache_scope(options) {
        return compute_module_key(path);
    }
}

test "package names are scoped lowercase identifiers" {
    assert is_package_name("acme/graph_kit");
    assert import_prefix("acme/graph_kit") == "acme.graph_kit";
    for bad in ["graphkit", "Acme/kit", "acme/kit-x", "acme/", "/kit", "a/b/c", ""] {
        assert not is_package_name(bad) , bad;
    }
}

test "a scoped package outside the consumer is a dependency" {
    t = _tree();
    assert package_root_of(t["util"]) == t["lib"];
    assert package_root_of(t["main"]) is None;
    assert is_dependency_module(t["util"], t["app"]);
    assert not is_dependency_module(t["util"], t["lib"]);
    assert not is_dependency_module(t["main"], t["app"]);
}

test "a dependency's key ignores the consumer's app and root but not its target" {
    t = _tree();
    with patch.dict(os.environ, cache_env(os.path.join(t["tmp"], "cache"))) {
        first = _key(
            t["util"], CompileOptions(project_root=t["app"], target_app="web")
        );
        second = _key(
            t["util"], CompileOptions(project_root=t["other"], target_app="api")
        );
        assert first == second;
        retargeted = _key(
            t["util"],
            CompileOptions(
                project_root=t["app"], native_target="wasm32-unknown-unknown"
            )
        );
        assert retargeted != first;
        own_a = _key(
            t["main"], CompileOptions(project_root=t["app"], target_app="web")
        );
        own_b = _key(
            t["main"], CompileOptions(project_root=t["app"], target_app="api")
        );
        assert own_a != own_b;
    }
}

test "resolving from inside a mounted package links nothing into it" {
    import from jaclang.project.modresolver { get_jac_search_paths }
    tmp = os.path.realpath(tempfile.mkdtemp());
    manifest = "[project]\nname = \"acme/core\"\nversion = \"1.0.0\"\n";
    mounts = os.path.join(tmp, "app", ".jac", "packages");
    vendored = os.path.join(mounts, "acme", "core");
    _write(os.path.join(vendored, "jac.toml"), manifest);
    _write(os.path.join(vendored, "text.jac"), "def shout -> int { return 1; }\n");
    paths = get_jac_search_paths(vendored);
    assert mounts in paths , paths;
    assert not os.path.lexists(os.path.join(vendored, ".jac")) , "a mounted package was linked into";
    standalone = os.path.join(tmp, "core");
    _write(os.path.join(standalone, "jac.toml"), manifest);
    get_jac_search_paths(standalone);
    assert os.path.islink(os.path.join(standalone, ".jac", "packages", "acme", "core"));
}
