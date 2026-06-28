"""Backend smoke test for the todo_app desktop example.

Boots main.jac through inprocess_dispatch (same path as the native desktop
host) and exercises create / read / toggle walkers. No webview required.

Run from the repo root:

    jac test jac/examples/todo_app/test_todo.jac -v
"""

import os;
import json;
import warnings;
import tempfile;
import from pathlib { Path }

glob _APP: str = str(Path(__file__).parent / "main.jac"),
     _BOOTED: bool = False;


def _backend_available -> bool {
    try {
        import starlette.testclient;
        import jac_scale.serve;
        return True;
    } except ImportError {
        return False;
    }
}


def _call(kind: str, name: str, fields: dict, anchor: str = "") -> dict {
    global _BOOTED;
    import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
        boot,
        dispatch
    }

    if not _BOOTED {
        graph_root = tempfile.mkdtemp(prefix="todo_example_");
        boot(_APP, os.path.join(graph_root, "graph"));
        _BOOTED = True;
    }
    with warnings.catch_warnings() {
        warnings.filterwarnings("ignore", category=DeprecationWarning);
        raw = dispatch(
            json.dumps(
                {
                    "kind": kind,
                    "name": name,
                    "node": anchor,
                    "fields": fields,
                    "token": ""
                }
            )
        );
    }
    return json.loads(raw);
}


def _first_todo(reply: dict) -> dict {
    reports = reply["body"]["data"]["reports"];
    first = reports[0];
    if isinstance(first, list) {
        return first[0];
    }
    return first;
}


test "create_todo persists a todo" {
    if not _backend_available() {
        print("[skip] jac-scale backend not installed");
        return;
    }
    reply = _call("walker", "create_todo", {"text": "buy milk"});
    assert reply["status"] == 200;
    assert reply["ok"] == True;
    todo = _first_todo(reply);
    assert todo["text"] == "buy milk";
    assert todo["done"] == False;
}


test "read_todos returns a created todo" {
    if not _backend_available() {
        print("[skip] jac-scale backend not installed");
        return;
    }
    _call("walker", "create_todo", {"text": "read me back"});
    reply = _call("walker", "read_todos", {});
    assert reply["status"] == 200;
    reports = reply["body"]["data"]["reports"];
    texts = [];
    for item in reports {
        if isinstance(item, list) {
            for todo in item {
                texts.append(todo["text"]);
            }
        } else {
            texts.append(item["text"]);
        }
    }
    assert "read me back" in texts;
}


test "toggle_todo flips done on the node" {
    if not _backend_available() {
        print("[skip] jac-scale backend not installed");
        return;
    }
    create = _call("walker", "create_todo", {"text": "toggle me"});
    todo = _first_todo(create);
    node_id = todo["_jac_id"];

    toggled = _call("walker", "toggle_todo", {}, anchor=node_id);
    assert toggled["status"] == 200;
    updated = _first_todo(toggled);
    assert updated["done"] == True;
}
