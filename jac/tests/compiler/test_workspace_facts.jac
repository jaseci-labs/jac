"""Workspace facts: the driver stamps app membership on every module.

A jac.toml with [apps] is a workspace. A module belongs to the app whose
root_dir contains it (nearest root_dir wins), a file-rooted app claims exactly its
entry file, and anything under no app root_dir is shared. A shared module that
defines walkers, pub defs or node/edge archetypes needs one owner; when two
serving apps could own it the driver emits E5107 unless an app pins it.
Cross-app uses that do not go through a bridge are the isolation laws
(E2039/W2039 for app-to-app, E2040/W2040 for shared-to-app).
"""

import os;
import tempfile;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.placement.workspace {
    AppSpec,
    app_fact_digest,
    app_for_path,
    owner_app_for_path,
    workspace_for_path
}

glob WORKSPACE_TOML: str = (
         '[project]\nname = "ws"\ndefault-app = "web"\n\n'
         + '[apps.web]\nkind = "web-app"\npath = "web"\n\n'
         + '[apps.mobile]\nkind = "mobile"\npath = "mobile"\n\n'
         + '[apps.social]\nkind = "service"\nentry-point = "core/social.jac"\n'
     );

def _app_of_spec(app: any) -> AppSpec {
    if app is None {
        raise AssertionError("expected an AppSpec, got None");
    }
    return app;
}

def _app_of(path: str) -> AppSpec {
    app = app_for_path(path);
    if app is None {
        raise AssertionError(f"no app owns {path}");
    }
    return app;
}


def _write(root_dir: str, rel: str, text: str) -> str {
    path = os.path.join(root_dir, rel);
    os.makedirs(os.path.dirname(path), exist_ok=True);
    with open(path, "w") as f {
        f.write(text);
    }
    return path;
}


def _workspace(tmp: str, toml: str = WORKSPACE_TOML) -> dict[str, str] {
    _write(tmp, "jac.toml", toml);
    return {
        "web": _write(tmp, "web/main.jac", "def:pub page -> int { return 1; }\n"),
        "web_util": _write(tmp, "web/util.jac", "def web_only -> int { return 2; }\n"),
        "mobile": _write(tmp, "mobile/main.jac", "def screen -> int { return 3; }\n"),
        "social": _write(
            tmp, "core/social.jac", "walker Greet { has name: str = \"\"; }\n"
        ),
        "util": _write(tmp, "core/util.jac", "def helper -> int { return 41; }\n"),
        "store": _write(tmp, "core/store.jac", "node Item { has label: str = \"\"; }\n")
    };
}


def _codes(prog: JacProgram, code: str) -> list {
    return [
        e
        for e in (prog.errors_had + prog.warnings_had)
        if e.code is not None and e.code.code == code
    ];
}


def _all_msgs(prog: JacProgram) -> str {
    return "\n".join([str(e) for e in (prog.errors_had + prog.warnings_had)]);
}


test "dir-rooted apps own the files under their root_dir" {
    with tempfile.TemporaryDirectory() as tmp {
        files = _workspace(tmp);
        ws = workspace_for_path(files["web"]);
        assert ws is not None and ws.explicit;
        assert sorted(ws.apps) == ["mobile", "social", "web"];
        assert ws.default_app == "web";
        assert _app_of(files["web"]).name == "web";
        assert _app_of(files["web_util"]).name == "web";
        assert _app_of(files["mobile"]).name == "mobile";
        assert [a.name for a in ws.serving_apps()] == ["web", "social"];
    }
}


test "a file-rooted app claims exactly its entry file" {
    with tempfile.TemporaryDirectory() as tmp {
        files = _workspace(tmp);
        social = app_for_path(files["social"]);
        assert social is not None and social.name == "social";
        assert social.file_rooted and social.root_dir == "";
        assert social.effective_route() == "/api/social";
        assert app_for_path(files["util"]) is None , "a sibling of the entry is shared";
        assert app_for_path(files["store"]) is None;
    }
}


test "the default app owns a shared module between two serving apps" {
    with tempfile.TemporaryDirectory() as tmp {
        files = _workspace(tmp);
        (owner, ambiguous) = owner_app_for_path(files["util"]);
        assert owner is not None and owner.name == "web" and not ambiguous , (
            "the default app owns shared server code when several apps serve"
        );
        (own2, amb2) = owner_app_for_path(files["web"]);
        assert own2 is not None and own2.name == "web" and not amb2;
    }
}


test "the driver stamps app facts on every module" {
    with tempfile.TemporaryDirectory() as tmp {
        files = _workspace(tmp);
        prog = JacProgram();
        web = prog.compile(files["web"], options=CompileOptions(no_cgen=True));
        assert not prog.errors_had , _all_msgs(prog);
        assert web.app == "web";
        assert web.app_root is not None
            and os.path.samefile(web.app_root, os.path.join(tmp, "web"));
        assert web.app_kind == "web-app";
        assert web.owner_app == "web";
        assert web.mobui_enforced_root is None;
        assert web.jac_project_root is not None
            and os.path.samefile(web.jac_project_root, tmp);
        mobile = JacProgram().compile(
            files["mobile"], options=CompileOptions(no_cgen=True)
        );
        assert mobile.app == "mobile" and mobile.app_kind == "mobile";
        assert mobile.mobui_enforced_root is not None
            and os.path.samefile(
                mobile.mobui_enforced_root, os.path.join(tmp, "mobile")
            ) , "kind = mobile at the app switches the guard on for its root_dir";
        mobile_spec = _app_of(files["mobile"]);
        assert mobile_spec.ui == "mobui" and _app_of(files["web"]).ui == "dom";
        assert not hasattr(mobile_spec, "client_kind") , "AppSpec carries ui, not client_kind";
        social = JacProgram().compile(
            files["social"], options=CompileOptions(no_cgen=True)
        );
        assert social.app == "social" and social.app_kind == "service";
        assert social.app_root is None , "a file-rooted app has no root_dir dir";
        assert social.owner_app == "social";
    }
}


test "a shared helper takes the target app's kind and needs no owner" {
    with tempfile.TemporaryDirectory() as tmp {
        files = _workspace(tmp);
        prog = JacProgram();
        util = prog.compile(
            files["util"],
            options=CompileOptions(
                no_cgen=True, target_app="web", app_kind="web-app", project_root=tmp
            )
        );
        assert util.app is None;
        assert util.app_kind == "web-app";
        assert util.owner_app is None , "a helper with no endpoints needs no owner";
        assert not _codes(prog, "E5107") , (
            "helpers are included in every reaching app's server closure"
        );
        bare = JacProgram().compile(
            files["util"], options=CompileOptions(no_cgen=True)
        );
        assert bare.app is None and bare.app_kind == "" and bare.owner_app is None;
    }
}


test "an ambiguous owner leaves owner_app unset (the workspace gate reports E5107)" {
    with tempfile.TemporaryDirectory() as tmp {
        files = _workspace(tmp, WORKSPACE_TOML.replace('default-app = "web"\n', ""));
        prog = JacProgram();
        store = prog.compile(files["store"], options=CompileOptions(no_cgen=True));
        assert store.app is None and store.owner_app is None;
        assert not _codes(prog, "E5107") , (
            "ownership ambiguity is a workspace-gate diagnostic, not a compile error"
        );
    }
}


test "an app-level server pin names the owner" {
    with tempfile.TemporaryDirectory() as tmp {
        toml = WORKSPACE_TOML
            + '\n[apps.web.placement.pins]\n"core.store" = "server"\n';
        files = _workspace(tmp, toml);
        (owner, ambiguous) = owner_app_for_path(files["store"]);
        assert owner is not None and owner.name == "web" and not ambiguous;
        prog = JacProgram();
        store = prog.compile(files["store"], options=CompileOptions(no_cgen=True));
        assert store.owner_app == "web" , f"got {store.owner_app}";
        assert not _codes(prog, "E5107") , _all_msgs(prog);
        web = _app_of_spec(app_for_path(files["web"]));
        assert web.pins == {"core.store": "server"} , "the overlay merges over the base pins";
    }
}


test "a workspace without [apps] is one implicit app" {
    with tempfile.TemporaryDirectory() as tmp {
        _write(tmp, "jac.toml", '[project]\nname = "hello"\n');
        main = _write(tmp, "main.jac", "with entry { print(1); }\n");
        ws = workspace_for_path(main);
        assert ws is not None and not ws.explicit;
        assert list(ws.apps) == ["hello"] and ws.default_app == "hello";
        app = ws.apps["hello"];
        assert app.implicit and app.kind == "" and app.ui == "";
        assert os.path.samefile(app.root_dir, tmp);
        assert os.path.samefile(app.`entry, main);
        (owner, ambiguous) = owner_app_for_path(main);
        assert owner is app and not ambiguous;
        mod = JacProgram().compile(main, options=CompileOptions(no_cgen=True));
        assert mod.app == "hello" and mod.owner_app == "hello" and mod.app_kind == "";
    }
}


test "the app fact digest tracks the facts that change codegen" {
    with tempfile.TemporaryDirectory() as tmp {
        files = _workspace(tmp);
        before = app_fact_digest(app_for_path(files["mobile"]));
        assert len(before) == 12;
        assert app_fact_digest(None) == "";
        assert app_fact_digest(app_for_path(files["web"])) != before;
        toml_path = os.path.join(tmp, "jac.toml");
        # The kind is the fact that flips the mobUI guard (there is no
        # client_kind any more), so it must perturb the digest.
        _write(
            tmp,
            "jac.toml",
            WORKSPACE_TOML.replace(
                '[apps.mobile]\nkind = "mobile"', '[apps.mobile]\nkind = "web-static"'
            )
        );
        st = os.stat(toml_path);
        os.utime(toml_path, (st.st_atime + 10, st.st_mtime + 10));
        after = app_fact_digest(app_for_path(files["mobile"]));
        assert after != before , "the kind is part of the digest";
        assert _app_of(files["mobile"]).ui == "dom";
    }
}

test "the mobUI guard follows the ui override and the app's kind" {
    # CompileOptions.ui replaces the old client_kind: "mobui" with a
    # project_root forces the guard on for that root, exactly as
    # client_kind="mobui" did, and a mobile app's modules get it by kind.
    with tempfile.TemporaryDirectory() as tmp {
        files = _workspace(tmp);
        forced = JacProgram().compile(
            files["web"], options=CompileOptions(ui="mobui", project_root=tmp)
        );
        assert forced.mobui_enforced_root is not None
            and os.path.samefile(forced.mobui_enforced_root, tmp) , (
            "ui=mobui with a project_root forces the guard on for that root"
        );
        plain = JacProgram().compile(
            files["web"], options=CompileOptions(ui="dom", project_root=tmp)
        );
        assert plain.mobui_enforced_root is None , "ui=dom never enforces";
        opts = CompileOptions(ui="mobui", project_root=tmp);
        assert opts.clone_for_native_import().ui == "mobui" , (
            "the ui override rides along into native-import clones"
        );
        assert not hasattr(opts, "client_kind") , "CompileOptions.client_kind was renamed to ui";
    }
}


test "using another app's private code is an isolation diagnostic" {
    with tempfile.TemporaryDirectory() as tmp {
        _workspace(tmp);
        consumer = _write(
            tmp,
            "web/leak.jac",
            "import from mobile.main { screen }\n\n"
                + "def use_it -> int { return screen(); }\n"
        );
        prog = JacProgram();
        prog.compile(consumer, options=CompileOptions(no_cgen=True));
        hits = _codes(prog, "W2039") + _codes(prog, "E2039");
        assert hits , f"expected W2039 for a cross-app use, got:\n{_all_msgs(prog)}";
        assert "'screen' belongs to app 'mobile'" in hits[0].msg , hits[0].msg;
        assert "app 'web'" in hits[0].msg , hits[0].msg;
    }
}


test "shared code may not depend on app modules" {
    with tempfile.TemporaryDirectory() as tmp {
        _workspace(tmp);
        shared = _write(
            tmp,
            "core/leak.jac",
            "import from web.util { web_only }\n\n"
                + "def use_it -> int { return web_only(); }\n"
        );
        prog = JacProgram();
        prog.compile(shared, options=CompileOptions(no_cgen=True));
        hits = _codes(prog, "W2040") + _codes(prog, "E2040");
        assert hits , f"expected W2040, got:\n{_all_msgs(prog)}";
        assert "Shared module 'leak.jac'" in hits[0].msg , hits[0].msg;
        assert "from app 'web'" in hits[0].msg , hits[0].msg;
    }
}


test "same-app and shared uses are not isolation diagnostics" {
    with tempfile.TemporaryDirectory() as tmp {
        _workspace(tmp);
        fine = _write(
            tmp,
            "web/fine.jac",
            "import from web.util { web_only }\n"
                + "import from core.util { helper }\n\n"
                + "def use_it -> int { return web_only() + helper(); }\n"
        );
        prog = JacProgram();
        prog.compile(fine, options=CompileOptions(no_cgen=True));
        for code in ("W2039", "E2039", "W2040", "E2040") {
            assert not _codes(prog, code) , f"{code} must not fire:\n{_all_msgs(prog)}";
        }
    }
}


test "a shared graph model follows its only service consumer across helper imports" {
    with tempfile.TemporaryDirectory(prefix="jac-owner-closure-") as tmp {
        _write(tmp, "jac.toml", WORKSPACE_TOML);
        _write(
            tmp,
            "web/main.jac",
            "import from core.social { count }\ndef:pub app -> JsxElement { return <div>{count()}</div>; }\n"
        );
        _write(
            tmp,
            "core/social.jac",
            "import from core.repository { count_items }\ndef:pub count -> int { return count_items(); }\n"
        );
        _write(
            tmp,
            "core/repository.jac",
            "import from core.model { Item }\ndef count_items -> int { root ++> Item(); return 1; }\n"
        );
        model = _write(tmp, "core/model.jac", "node Item { has label: str = \"\"; }\n");
        (owner, ambiguous) = owner_app_for_path(model);
        assert owner is not None;
        assert owner.name == "social" and not ambiguous , (
            "web reaches the service boundary, not the service's private graph model"
        );
    }
}


test "shared ownership and cache keys follow changes to app import roots" {
    import from jaclang.compiler.driver.jir { module_env_fingerprint }
    with tempfile.TemporaryDirectory(prefix="jac-owner-change-") as tmp {
        files = _workspace(tmp);
        _write(tmp, "core/social.jac", "import from core.store { Item }\n");
        (owner, _) = owner_app_for_path(files["store"]);
        assert owner is not None and owner.name == "social";
        before = module_env_fingerprint(files["store"]);
        _write(tmp, "web/new_page.jac", "import from core.store { Item }\n");
        (shared, _) = owner_app_for_path(files["store"]);
        assert shared is not None and shared.name == "web";
        assert module_env_fingerprint(files["store"]) != before;
        os.remove(os.path.join(tmp, "web/new_page.jac"));
        (restored, _) = owner_app_for_path(files["store"]);
        assert restored is not None and restored.name == "social";
        assert module_env_fingerprint(files["store"]) == before;
    }
}
