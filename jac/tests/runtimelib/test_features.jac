"""Feature function sync tests -- migrated from test_features.py."""

import inspect;
import pluggy;
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
