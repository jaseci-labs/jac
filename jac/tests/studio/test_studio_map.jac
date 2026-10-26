"""The architecture map: one package level at a time, and the context it hands an agent."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.studio.context { context_blocks }
import from jaclang.studio.graph { edge_wires, graph_level, parent_scope, scope_for }
import from jaclang.studio.model { ProjectModel }
import from tests.studio.shop_fixture { make_shop }

def shop_model(tmp: str) -> ProjectModel {
    model = ProjectModel(root_dir=str(make_shop(Path(tmp) / "shop")));
    model.build(index=False);
    return model;
}

test "a map level orders providers first and finds the backward wire and the cycle" {
    with TemporaryDirectory() as tmp {
        model = shop_model(tmp);
        lvl = graph_level(model, "");
        assert [nd.label for nd in lvl.nodes] == ["core", "app", "cli"];
        assert [nd.layer for nd in lvl.nodes] == [0, 1, 2];
        feeds = lvl.edge_of("core", "app");
        assert feeds is not None and feeds.count() == 8;
        back = lvl.back_edges();
        assert [(e.src, e.dst, e.count(), e.violations) for e in back]
            == [("app", "core", 1, 1)];
        assert lvl.cycles == [["core", "app"]];
        assert len(edge_wires(model, "core", "app")) == 8;
        assert scope_for(model, "core.models") == "core";
        assert parent_scope(model, "core") == "";
        inner = graph_level(model, "core");
        assert len(inner.nodes) == 5;
        part = graph_level(model, "", {"cli", "app.views", "app.api"});
        assert [nd.label for nd in part.nodes] == ["app", "cli"];
    }
}

test "context from a narrowed map keeps the slice it was taken from" {
    with TemporaryDirectory() as tmp {
        model = shop_model(tmp);
        blocks = context_blocks(
            model,
            [
                "map:?slice=cli",
                "deps:core=>app?blast=core.log",
                "wire:core.log->app.api.serve"
            ]
        );
        texts = [b["resource"]["text"] for b in blocks];
        assert len(texts) == 3;
        assert "Only the 7 module(s) in the slice of cli (at import time)"
            in texts[0] , texts[0][:200];
        assert "Wires from core to app (1):" in texts[1] , texts[1][:300];
        assert "core.log ++> app.api" in texts[1];
        assert "serve" in texts[2];
    }
}
