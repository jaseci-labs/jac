"""The studio's project model: modules, symbols, wires, rules and the index cache."""
import io;
import os;
import json;
import from contextlib { redirect_stdout }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.frontend.host { HostServices, active_host, install_host }
import from jaclang.studio.app { cmd_model }
import from jaclang.studio.model { ProjectModel, StImpl }
import from tests.studio.shop_fixture { make_shop }

test "the model reads the wiring, indexes symbols and sees a new impl annex" {
    with TemporaryDirectory() as tmp {
        base = make_shop(Path(tmp) / "shop");
        model = ProjectModel(root_dir=str(base));
        model.build();
        mods = {
            k
            for (k, m) in model.modules.items()
            if m.kind == "module"
        };
        assert mods
            == {
                "app.admin",
                "app.api",
                "app.views",
                "cli",
                "core.fmt",
                "core.log",
                "core.models",
                "core.store",
                "core.util"
            } , mods;
        assert "core.models.Item.label" in model.symbols , sorted(model.symbols);
        assert {r.name for r in model.rules}
            == {"CoreFeedsApp", "AppFeedsCli", "Unused"};
        bad = [
            w
            for w in model.wires
            if w.violation
        ];
        assert len(bad) == 1 and bad[0].violation.startswith("E2099") , [
            w.violation for w in bad
        ];
        assert not bad[0].rules , "a rejected wire is admitted by no rule";
        scoped = [
            w
            for w in model.wires
            if w.scope
        ];
        assert [(w.provider, w.consumer, w.scope) for w in scoped]
            == [("core.log", "app.api", "serve")];
        (base / "core" / "models.impl.jac").write_text(
            'impl Item.label -> str {\n    return self.name;\n}\n'
        );
        again = ProjectModel(root_dir=str(base));
        again.build();
        impls = [
            s
            for s in again.symbols.values()
            if isinstance(s, StImpl) and s.file.endswith("models.impl.jac")
        ];
        assert impls , "the index cache must notice an impl annex added beside an unchanged module";
        out = io.StringIO();
        with redirect_stdout(out) {
            rc = cmd_model(str(base), ["core.models.Item"], True);
        }
        found = json.loads(out.getvalue());
        assert rc == 0 and found["key"] == "core.models.Item" , out.getvalue()[:300];
    }
}

test "refreshing a package keeps its children's symbols, and new files are found" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp) / "pkgs";
        (base / "pkg").mkdir(parents=True);
        (base / "jac.toml").write_text("[project]\nname = \"pkgs\"\n");
        (base / "pkg" / "__init__.jac").write_text(
            "def top -> int {\n    return 1;\n}\n"
        );
        (base / "pkg" / "child.jac").write_text(
            "def leaf -> int {\n    return 2;\n}\n"
        );
        model = ProjectModel(root_dir=str(base));
        ambient = active_host();
        install_host(HostServices());
        try {
            model.build();
        } finally {
            install_host(ambient);
        }
        child = [
            k
            for k in model.symbols
            if k.endswith(".leaf")
        ];
        assert child , (
            f"no symbols indexed (ambient host {type(ambient).__name__}): "
            + str({k: (m.kind, m.error) for (k, m) in model.modules.items()})
        );
        model.refresh(str(base / "pkg" / "__init__.jac"));
        assert child[0] in model.symbols , "refreshing the package dropped a child module's symbols";
        extra = base / "pkg" / "extra.jac";
        extra.write_text("def more -> int {\n    return 3;\n}\n");
        found = model.stale_files();
        assert os.path.realpath(str(extra)) in found , found;
        model.refresh(str(extra));
        assert any([k.endswith(".more") for k in model.symbols]) , sorted(
            model.symbols
        );
        assert os.path.realpath(str(extra)) not in model.stale_files();
        extra.unlink();
        for path in model.stale_files() {
            model.refresh(path);
        }
        assert not any([k.endswith(".more") for k in model.symbols]) , "a deleted module's symbols remain";
        assert not any([m.file.endswith("extra.jac") for m in model.modules.values()]);
        assert not model.stale_files() , "a deleted file is retried forever";
    }
}
