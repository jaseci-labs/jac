"""The studio's screens, driven through a virtual terminal with the shop project open."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.osprey.ui.virtual_terminal { VirtualTerminal }
import os;
import from jaclang.studio.gate { EditGate, EditReview, symbol_changes }
import from jaclang.studio.insight { tour_text }
import from jaclang.studio.model { ProjectModel }
import from jaclang.studio.tui {
    Studio,
    handle_key,
    open_approval,
    open_doc,
    paint,
    rebuild_nav,
    rerun_reviews
}
import from tests.studio.shop_fixture { make_shop }

def open_studio(tmp: str) -> Studio {
    base = make_shop(Path(tmp) / "shop");
    model = ProjectModel(root_dir=str(base));
    model.build();
    app = Studio(root_dir=str(base), model=model);
    app.term = VirtualTerminal(columns=150, rows=40);
    rebuild_nav(app);
    return app;
}

def screen(app: Studio) -> str {
    paint(app);
    term = app.term;
    assert isinstance(term, VirtualTerminal);
    return "\n".join(term.capture_cells());
}

def press(app: Studio, keys: list[str]) -> str {
    for k in keys {
        handle_key(app, k);
    }
    return screen(app);
}

test "the workspace paints its panes and the project tree" {
    with TemporaryDirectory() as tmp {
        text = screen(open_studio(tmp));
        for part in ["NAVIGATOR", "AGENT", "CONTEXT", "PROMPT", "app", "core", "cli"] {
            assert part in text , f"missing {part!r}:\n{text}";
        }
    }
}

test "m opens the map with the cycle marked and the backward wire below the diagonal" {
    with TemporaryDirectory() as tmp {
        text = press(open_studio(tmp), ["m"]);
        assert "MAP  project" in text
            and "3 groups" in text
            and "1 backward" in text , text;
        assert "↻core" in text and "↻app" in text , text;
    }
}

test "the layers and issues views show the layering and the violation" {
    with TemporaryDirectory() as tmp {
        app = open_studio(tmp);
        layers = press(app, ["m", "2"]);
        for part in ["L0", "L1", "L2"] {
            assert part in layers , layers;
        }
        issues = press(app, ["3"]);
        assert "Rule violations" in issues and "app → core" in issues , issues;
    }
}

test "s narrows the map to a slice and x clears it" {
    with TemporaryDirectory() as tmp {
        app = open_studio(tmp);
        sliced = press(app, ["m", "down", "down", "d", "s"]);
        assert "slice of cli" in sliced , sliced;
        cleared = press(app, ["x"]);
        assert "slice of cli" not in cleared and "3 groups" in cleared , cleared;
    }
}

test "an edit waits for the compiler's verdict before it can be accepted" {
    with TemporaryDirectory() as tmp {
        app = open_studio(tmp);
        app.gate = EditGate(root_dir=app.root_dir);
        target = str(Path(app.root_dir) / "core" / "util.jac");
        app.pending.append(
            {
                "type": "write",
                "data": {
                    "path": target,
                    "content": "def slug -> str {}\n",
                    "request_id": 1
                },
                "done": False
            }
        );
        open_approval(app);
        handle_key(app, "a");
        assert len(app.pending) == 1 , "the edit must not be accepted while it is still being checked";
        assert "still checking" in app.flash , app.flash;
    }
}

test "the tour opens in a sheet over the workspace" {
    with TemporaryDirectory() as tmp {
        app = open_studio(tmp);
        open_doc(app, "Tour of the project", tour_text(app.model, ""));
        text = screen(app);
        assert "Tour of the project" in text and "A tour of shop" in text , text;
    }
}

test "rejecting one file rechecks the edits that were checked against it" {
    with TemporaryDirectory() as tmp {
        app = open_studio(tmp);
        rejected = os.path.realpath(str(Path(app.root_dir) / "core" / "util.jac"));
        other = os.path.realpath(str(Path(app.root_dir) / "core" / "store.jac"));
        def write(path: str, saw: list[str], done: bool) -> dict[str, any] {
            req: dict[str, any] = {
                "type": "write",
                "data": {"path": path, "content": "", "request_id": 1},
                "done": done,
                "seen": done
            };
            if done {
                req["review"] = EditReview(
                    path=path, old_text="", new_text="", seen_staged=saw
                );
            }
            return req;
        }
        first = write(rejected, [], True);
        against = write(other, [rejected], True);
        apart = write(other, [], True);
        running = write(other, [], False);
        app.pending = [first, against, apart, running];
        rerun_reviews(app, first, rejected);
        assert "review" not in against and not against["seen"] , "a review that saw the rejected text runs again";
        assert "review" in apart , "a review that did not see it is kept";
        assert running.get("recheck") , "a review still running is rechecked when it finishes";
    }
}

test "toggling symbol changes keeps exactly the ones left ticked" {
    with TemporaryDirectory() as tmp {
        app = open_studio(tmp);
        path = str(Path(app.root_dir) / "core" / "store.jac");
        old = Path(path).read_text();
        new = old.replace("return 0;", "return 10;").replace(
            "return n;", "return n + 1;"
        );
        rv = EditReview(
            path=path,
            old_text=old,
            new_text=new,
            symbol_changes=symbol_changes(old, new, path)
        );
        req: dict[str, any] = {
            "type": "write",
            "data": {"path": path, "content": new, "request_id": 1},
            "done": True,
            "seen": True,
            "review": rv
        };
        app.pending.append(req);
        open_approval(app);
        for k in ["1", "2", "1"] {
            handle_key(app, k);
        }
        assert req["keep"] == {"load"} , req.get("keep");
    }
}
