"""The studio's project model: modules, symbols, wires, rules and the index cache."""
import io;
import json;
import from contextlib { redirect_stdout }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
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
