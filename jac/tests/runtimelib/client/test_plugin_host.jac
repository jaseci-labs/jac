"""Unit tests for the plugin host dispatch logic.

Tests the PluginHost registry, dispatch routing, error handling, and push-event
emission using mock plugins. These tests run in pure Python (no webview needed).
"""
import json;
import sys;
import jaclang;
import from pathlib { Path }

# The desktop plugin modules ship inside jaclang core at
# jaclang/runtimelib/client/targets/desktop/plugin/ and import each other with
# bare names (e.g. `import from desktop_plugin`), so that dir must be on
# sys.path before the bare imports below resolve. Top-level statements run in
# source order, so this entry block puts it on the path before the imports.
glob _plugin_dir = str(
         Path(jaclang.__file__).parent / "runtimelib" / "client" / "targets" / "desktop" / "plugin"
     );

with entry {
    if _plugin_dir not in sys.path {
        sys.path.insert(0, _plugin_dir);
    }
}

import from desktop_plugin { PluginError, DesktopPlugin }
import from plugin_host { PluginHost }


"""A mock plugin that records calls and returns configurable results."""
obj MockPlugin(DesktopPlugin) {
    has calls: list,
        _responses: dict;

    def init(name: str = "mock") {
        # DesktopPlugin now exposes plugin_name as a field (no-arg init), so set
        # it directly instead of passing a name through super.init().
        self.plugin_name = name;
        self.calls = [];
        self._responses = {};
    }

    def set_response(command: str, result: dict) {
        self._responses[command] = result;
    }

    def handle(command: str, args: dict) -> dict {
        self.calls.append({"command": command, "args": args});
        if command in self._responses {
            return self._responses[command];
        }
        raise PluginError(
            "UNKNOWN_COMMAND", f"Plugin '{self.plugin_name}' has no command '{command}'"
        );
    }
}


"""A plugin whose handle() always raises a PluginError (declared at module level:
a nested archetype inheriting an imported one fails to construct)."""
obj FailPlugin(DesktopPlugin) {
    has plugin_name: str = "fail";

    def handle(command: str, args: dict) -> dict {
        raise PluginError("FORBIDDEN", "Access denied");
    }
}


"""A plugin whose handle() raises an unexpected (non-PluginError) exception."""
obj CrashPlugin(DesktopPlugin) {
    has plugin_name: str = "crash";

    def handle(command: str, args: dict) -> dict {
        raise RuntimeError("boom");
    }
}


"""Dispatch routes to the correct plugin by name."""
test "dispatch routes to correct plugin" {
    host = PluginHost();
    foo = MockPlugin("foo");
    bar = MockPlugin("bar");
    bar.set_response("ping", {"result": "pong"});
    host.register("foo", foo);
    host.register("bar", bar);

    result = json.loads(
        host.dispatch(
            json.dumps({"plugin": "bar", "command": "ping", "args": {"x": 1}})
        )
    );
    assert result["ok"] == True;
    assert result["data"]["result"] == "pong";
    assert len(bar.calls) == 1;
    assert bar.calls[0]["command"] == "ping";
    assert len(foo.calls) == 0;
}

"""Dispatch returns PLUGIN_NOT_FOUND for unregistered plugin."""
test "dispatch returns PLUGIN_NOT_FOUND for unknown plugin" {
    host = PluginHost();
    result = json.loads(
        host.dispatch(json.dumps({"plugin": "nonexistent", "command": "x", "args": {}}))
    );
    assert result["ok"] == False;
    assert result["error"]["code"] == "PLUGIN_NOT_FOUND";
}

"""Dispatch returns UNKNOWN_COMMAND when plugin doesn't handle it."""
test "dispatch returns error for unhandled command" {
    host = PluginHost();
    mock = MockPlugin("test");
    host.register("test", mock);

    result = json.loads(
        host.dispatch(
            json.dumps({"plugin": "test", "command": "unhandled", "args": {}})
        )
    );
    assert result["ok"] == False;
    assert result["error"]["code"] == "UNKNOWN_COMMAND";
}

"""Dispatch catches PluginError and returns structured error."""
test "dispatch catches PluginError" {
    host = PluginHost();
    host.register("fail", FailPlugin());
    result = json.loads(
        host.dispatch(json.dumps({"plugin": "fail", "command": "do_it", "args": {}}))
    );
    assert result["ok"] == False;
    assert result["error"]["code"] == "FORBIDDEN";
    assert result["error"]["message"] == "Access denied";
}

"""Dispatch catches unexpected exceptions as INTERNAL_ERROR."""
test "dispatch catches unexpected exceptions" {
    host = PluginHost();
    host.register("crash", CrashPlugin());
    result = json.loads(
        host.dispatch(json.dumps({"plugin": "crash", "command": "explode", "args": {}}))
    );
    assert result["ok"] == False;
    assert result["error"]["code"] == "INTERNAL_ERROR";
    assert "boom" in result["error"]["message"];
}

"""Dispatch passes args correctly to the plugin."""
test "dispatch passes args correctly" {
    host = PluginHost();
    mock = MockPlugin("test");
    host.register("test", mock);

    host.dispatch(
        json.dumps(
            {"plugin": "test", "command": "do", "args": {"path": "/tmp", "flag": True}}
        )
    );
    assert mock.calls[0]["args"]["path"] == "/tmp";
    assert mock.calls[0]["args"]["flag"] == True;
}

"""Dispatch handles malformed JSON gracefully."""
test "dispatch handles malformed JSON" {
    host = PluginHost();
    result = json.loads(host.dispatch("not json at all"));
    assert result["ok"] == False;
    assert result["error"]["code"] == "INTERNAL_ERROR";
}

"""Dispatch handles missing fields gracefully."""
test "dispatch handles missing fields" {
    host = PluginHost();
    result = json.loads(host.dispatch(json.dumps({})));
    assert result["ok"] == False;
    assert result["error"]["code"] == "PLUGIN_NOT_FOUND";
}

"""PluginError stores code and message correctly."""
test "plugin error stores code and message" {
    err = PluginError("TEST_CODE", "test message");
    assert err.code == "TEST_CODE";
    assert err.message == "test message";
    assert "TEST_CODE" in str(err);
}

"""MockPlugin returns configured responses."""
test "mock plugin returns configured responses" {
    host = PluginHost();
    mock = MockPlugin("test");
    mock.set_response("hello", {"greeting": "world"});
    host.register("test", mock);

    result = json.loads(
        host.dispatch(json.dumps({"plugin": "test", "command": "hello", "args": {}}))
    );
    assert result["ok"] == True;
    assert result["data"]["greeting"] == "world";
}

"""Emit is a no-op when webview is not set up."""
test "emit is no-op without webview setup" {
    host = PluginHost();
    # Should not raise
    host.emit("test:event", {"key": "value"});
}
