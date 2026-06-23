"""Tests for the core client entry-generator registration.

These tests exercise the registration hooks in the core client framework
(``jaclang.runtimelib.client.entry_generators``) — the web and native
generators ship with core and register via ``register_web_entry_generators``
and ``register_native_entry_generators``.
"""

import from jaclang.runtimelib.entry_generators {
    get_entry_generator,
    has_entry_generator,
    clear_entry_generators
}
import from jaclang.runtimelib.client.entry_generators.web_entry {
    build_simple_react_entry_script,
    build_web_error_overlay_entry_script,
    register_web_entry_generators
}
import from jaclang.runtimelib.client.entry_generators.native_entry {
    register_native_entry_generators,
    build_registry_native_entry_script
}

test "web plugin registration aligns canonical web generators" {
    clear_entry_generators();
    assert not has_entry_generator("web");
    assert not has_entry_generator("web:error_overlay");

    register_web_entry_generators();

    assert has_entry_generator("web");
    assert has_entry_generator("web:error_overlay");
    web_fn = get_entry_generator("web");
    overlay_fn = get_entry_generator("web:error_overlay");
    assert web_fn("main") == build_simple_react_entry_script("main");
    assert overlay_fn("app.jac", "boom") == build_web_error_overlay_entry_script(
        "app.jac", "boom"
    );
}

test "web plugin registration composes with builtin lazy fallback" {
    clear_entry_generators();
    builtin = get_entry_generator("web");
    assert has_entry_generator("web");

    register_web_entry_generators();

    assert has_entry_generator("web:error_overlay");
    fn = get_entry_generator("web");
    assert builtin("main") == fn("main");
    assert fn("main") == build_simple_react_entry_script("main");
}

test "native plugin registration populates runtime registry" {
    clear_entry_generators();
    assert not has_entry_generator("react-native");
    assert not has_entry_generator("native");

    register_native_entry_generators();

    assert has_entry_generator("react-native");
    assert has_entry_generator("native");

    fn = get_entry_generator("react-native");
    script = fn("main");
    assert "AppRegistry" in script;
    assert "registerComponent" in script;
    assert 'from "./main.js"' in script;
    assert "app as JacApp" in script;
    direct = build_registry_native_entry_script("main");
    assert direct == script;
    assert get_entry_generator("native")("main") == script;
}
