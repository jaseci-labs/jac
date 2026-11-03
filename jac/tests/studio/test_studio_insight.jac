"""Readings of the wiring: roles, interfaces, rules, slices, clusters, the tour and the diff."""
import subprocess;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.studio.bridge { StudioQueries }
import from jaclang.studio.insight {
    arch_diff,
    cluster_report,
    intent_report,
    interface_of,
    module_roles,
    reach,
    roles_text,
    tour_text
}
import from jaclang.studio.model { ProjectModel }
import from tests.studio.shop_fixture { make_shop }

def shop_model(tmp: str) -> ProjectModel {
    model = ProjectModel(root_dir=str(make_shop(Path(tmp) / "shop")));
    model.build(index=False);
    return model;
}

test "roles sort modules by how they are wired, and the agent tool reports them" {
    with TemporaryDirectory() as tmp {
        model = shop_model(tmp);
        roles = {r.key: r.role for r in module_roles(model).roles};
        assert roles["cli"] == "entry";
        assert roles["app.admin"] == "entry";
        assert roles["core.util"] == "leaf";
        assert roles["core.store"] == "relay";
        reply = StudioQueries(model=model).handle("insight", {"view": "roles"});
        assert reply["text"] == roles_text(module_roles(model, ""));
    }
}

test "an interface lists the names that leave a package and who uses each" {
    with TemporaryDirectory() as tmp {
        iface = interface_of(shop_model(tmp), "core");
        users = {f"{c.provider}.{c.name}": c.others for c in iface.exports};
        assert users["core.fmt.money"] == ["app.admin", "app.api", "app.views"];
        assert users["core.models.Item"] == ["app.views"];
        assert [f"{c.provider}.{c.name}" for c in iface.imports]
            == ["app.views.render"];
        assert iface.out_by_group == {"app": 8};
        assert any(["single outside user" in h for h in iface.hints]);
    }
}

test "the rules report counts admitted wires, unused permissions and violations" {
    with TemporaryDirectory() as tmp {
        rep = intent_report(shop_model(tmp));
        assert (rep.crossing, rep.admitted) == (11, 10);
        uses = {r.name: r.wires for r in rep.rules};
        assert uses == {"CoreFeedsApp": 8, "AppFeedsCli": 2, "Unused": 0};
        assert [r.name for r in rep.dead_rules()] == ["Unused"];
        assert [(a.source, a.target) for (r, a) in rep.unused_arms()]
            == [("core.*", "cli")];
        assert list(rep.violations) == ["E2099"];
    }
}

test "a slice and a blast radius separate import time from function-level wires" {
    with TemporaryDirectory() as tmp {
        model = shop_model(tmp);
        up = reach(model, "cli", "up");
        assert len(up.modules()) - 1 == 7;
        assert up.eager == 6 , "core.log loads only inside app.api.serve";
        assert "core.log" not in {m for step in up.eager_steps for m in step};
        down = reach(model, "core.models.Item", "down");
        assert down.name == "Item";
        assert sorted([w.consumer for w in down.direct]) == ["app.views", "core.store"];
    }
}

test "clusters compare the wiring with the packages and flag a misplaced module" {
    with TemporaryDirectory() as tmp {
        rep = cluster_report(shop_model(tmp));
        members = [m for cl in rep.clusters for m in cl.members];
        assert sorted(members) == sorted(set(members)) and len(members) == 9;
        assert 0.0 <= rep.purity <= 1.0;
        assert [(m.key, m.best) for m in rep.misplaced] == [("core.fmt", "app")];
    }
}

test "the tour walks the layers and points at where they break" {
    with TemporaryDirectory() as tmp {
        text = tour_text(shop_model(tmp));
        for part in [
            "# A tour of shop",
            "## How it is layered",
            "### Layer 0",
            "**core**",
            "## Where the layering breaks",
            "Cycle 1: core, app",
            "**Unused**"
        ] {
            assert part in text , f"missing {part!r} in the tour";
        }
    }
}

test "the diff reports new wires against the merge base, a duplicate pair included" {
    with TemporaryDirectory() as tmp {
        base = make_shop(Path(tmp) / "shop");
        def git(args: list[str]) {
            subprocess.run(
                ["git", "-c", "user.name=t", "-c", "user.email=t@t", "-C", str(base)]
                    + args,
                check=True,
                capture_output=True
            );
        }
        git(["init", "-q"]);
        git(["add", "-A"]);
        git(["commit", "-q", "-m", "shop"]);
        arch = base / "archwire.jac";
        arch.write_text(
            arch.read_text().replace(
                "    app.views ++> core.store { render }\n",
                "    app.views ++> core.store { render }\n    core.store ++> app.views { flush }\n    app.api ++> core.models { serve }\n"
            )
        );
        model = ProjectModel(root_dir=str(base));
        model.build(index=False);
        d = arch_diff(model, "HEAD");
        assert not d.error , d.error;
        assert sorted([(w.provider, w.consumer) for w in d.added])
            == [("app.api", "core.models"), ("core.store", "app.views")];
        assert not d.names_added and not d.names_removed , "a second wire is not a change to the first";
        assert [(w.provider, w.consumer) for w in d.new_violations]
            == [("app.api", "core.models")];
    }
}
