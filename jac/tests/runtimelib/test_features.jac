"""Feature function sync tests -- migrated from test_features.py."""

import inspect;
import jaclang.jac0core.plugin as pluggy;
import from jaclang.jac0core.runtime {
    JacRuntimeImpl,
    JacRuntimeInterface,
    JacRuntimeSpec
}

def get_methods(cls: type) -> list[str] {
    methods: list[str] = [];
    for (name, value) in inspect.getmembers(cls, predicate=inspect.isfunction) {
        value = getattr(cls, name);
        signature = inspect.signature(value);
        new_parameters: list = [];
        for (_, param) in signature.parameters.items() {
            new_param = param.replace(default=inspect.Parameter.empty);
            new_parameters.append(new_param);
        }
        signature = signature.replace(parameters=new_parameters);
        methods.append(f"{name}{signature}");
    }
    return methods;
}

test "feature funcs synced" {
    jac_feature_methods = get_methods(JacRuntimeInterface);
    jac_feature_defaults_methods = get_methods(JacRuntimeImpl);
    jac_feature_spec_methods = get_methods(JacRuntimeSpec);

    assert len(jac_feature_methods) > 5;
    assert jac_feature_spec_methods == jac_feature_defaults_methods;
    for i in jac_feature_spec_methods {
        assert i in jac_feature_methods;
    }
}

test "hookable layer wiring" {
    import jaclang.jac0core.jaclib as jaclib;
    import from jaclang.jac0core.runtime { plugin_manager }

    # The 20 @hookable methods are the dispatchable hooks; firstresult comes
    # from the marker (register_project_template aggregates, the rest win-first).
    assert not plugin_manager.hook.register_project_template._firstresult;
    assert plugin_manager.hook.call_llm._firstresult;

    # A direct (non-@hookable) method has no hook caller at all.
    assert not hasattr(plugin_manager.hook, 'get_object');

    # jaclib captures its hook bindings at import; they must be the dispatching
    # proxies installed on the interface, not the raw core defaults -- otherwise
    # codegen-emitted call_llm/get_mtir/etc. would silently bypass plugins.
    for n in ['call_llm', 'acall_llm', 'get_mtir', 'by_operator', 'create_j_context'] {
        assert getattr(jaclib, n) is getattr(JacRuntimeInterface, n);
    }
}

test "multiple plugins" {
    pm = pluggy.PluginManager("jac");
    hookimpl = pluggy.HookimplMarker("jac");

    class AnotherPlugin {
        @hookimpl
        static def setup -> str {
            return "I'm here";
        }
    }

    pm.register(AnotherPlugin());
    assert len(pm.hook.setup.get_hookimpls()) == 1;
    results = pm.hook.setup();
    assert "I'm here" in results;
}
