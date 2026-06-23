"""Tests for the entry-generator registry.

The registry is the seam between core machinery (HMR, eject, the shared
client compiler step) and the active client target. These tests exercise it
in isolation — they do not need a built bundle, only the contract surface
in `jaclang.runtimelib.entry_generators` and the canonical generators in
`jaclang.runtimelib.client.entry_generators`.
"""

import pytest;
import from jaclang.runtimelib.entry_generators {
    register_entry_generator,
    get_entry_generator,
    has_entry_generator,
    clear_entry_generators
}
import from jaclang.runtimelib.client.entry_generators.web_entry {
    build_simple_react_entry_script,
    build_web_error_overlay_entry_script
}

test "registered generator is returned by get_entry_generator" {
    clear_entry_generators();
    def stub(entry_module: str, install_global_handlers: bool = True) -> str {
        return f"stub({entry_module},{install_global_handlers})";
    }
    register_entry_generator("test", stub);
    fn = get_entry_generator("test");
    result = fn("main", install_global_handlers=False);
    assert result == "stub(main,False)";
    clear_entry_generators();
}

test "get_entry_generator raises LookupError when target is missing" {
    clear_entry_generators();
    raised = False;
    msg = "";
    try {
        get_entry_generator("never_registered");
    } except LookupError as e {
        raised = True;
        msg = str(e);
    }
    assert raised;
    assert "never_registered" in msg;
    assert "core client framework" in msg;
    assert not has_entry_generator("web");
}

test "get_entry_generator lazy-registers the builtin web generator only for web" {
    clear_entry_generators();
    assert not has_entry_generator("web");
    fn = get_entry_generator("web");
    assert has_entry_generator("web");
    direct = build_simple_react_entry_script("main", install_global_handlers=False);
    via_registry = fn("main", install_global_handlers=False);
    assert direct == via_registry;
}

test "core web fallback matches canonical simple react bootstrap" {
    import from jaclang.runtimelib.entry_generators { _build_simple_react_entry_script }
    assert _build_simple_react_entry_script("main") == build_simple_react_entry_script(
        "main"
    );
    assert _build_simple_react_entry_script("main", install_global_handlers=False) == build_simple_react_entry_script(
        "main", install_global_handlers=False
    );
}

test "core web fallback matches canonical error overlay bootstrap" {
    import from jaclang.runtimelib.entry_generators {
        _build_web_error_overlay_entry_script
    }
    assert _build_web_error_overlay_entry_script("app.jac", "boom") == (
        build_web_error_overlay_entry_script("app.jac", "boom")
    );
}

test "get_entry_generator lazy-registers the builtin web error overlay generator" {
    clear_entry_generators();
    assert not has_entry_generator("web:error_overlay");
    fn = get_entry_generator("web:error_overlay");
    assert has_entry_generator("web:error_overlay");
    direct = build_web_error_overlay_entry_script("app.jac", "boom");
    via_registry = fn("app.jac", "boom");
    assert direct == via_registry;
}

test "has_entry_generator reflects registration state" {
    clear_entry_generators();
    assert not has_entry_generator("web");
    def stub2(entry_module: str, install_global_handlers: bool = True) -> str {
        return "x";
    }
    register_entry_generator("web", stub2);
    assert has_entry_generator("web");
    clear_entry_generators();
    assert not has_entry_generator("web");
}

test "re-registering the same target overrides the previous generator" {
    clear_entry_generators();
    def first(entry_module: str, install_global_handlers: bool = True) -> str {
        return "first";
    }
    def second(entry_module: str, install_global_handlers: bool = True) -> str {
        return "second";
    }
    register_entry_generator("web", first);
    register_entry_generator("web", second);
    assert get_entry_generator("web")("main") == "second";
    clear_entry_generators();
}
