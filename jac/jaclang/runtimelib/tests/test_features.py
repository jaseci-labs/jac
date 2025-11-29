"""Tests for Jac parser."""

import inspect

import pluggy

from jaclang.runtimelib.runtime import (
    JacRuntimeImpl,
    JacRuntimeInterface,
    JacRuntimeSpec,
)


def get_methods(cls: type) -> list[str]:
    """Get a list of method names with their signatures for a given class."""
    methods = []
    for name, value in inspect.getmembers(cls, predicate=inspect.isfunction):
        value = getattr(cls, name)
        # Get the signature using inspect
        signature = inspect.signature(value)
        new_parameters = []
        for (
            _,
            param,
        ) in signature.parameters.items():  # to strip defaults
            new_param = param.replace(default=inspect.Parameter.empty)
            new_parameters.append(new_param)
        signature = signature.replace(parameters=new_parameters)
        methods.append(f"{name}{signature}")
    return methods


def test_feature_funcs_synced():
    """Test if JacRuntime, JacRuntimeDefaults, and JacRuntimeSpec have synced methods."""
    # Get methods of each class
    jac_feature_methods = get_methods(JacRuntimeInterface)
    jac_feature_defaults_methods = get_methods(JacRuntimeImpl)
    jac_feature_spec_methods = get_methods(JacRuntimeSpec)

    # Check if all methods are the same in all classes
    assert len(jac_feature_methods) > 5
    assert jac_feature_spec_methods == jac_feature_defaults_methods
    for i in jac_feature_spec_methods:
        assert i in jac_feature_methods


def test_multiple_plugins():
    """Test that multiple plugins can implement the same hook."""
    pm = pluggy.PluginManager("jac")
    hookimpl = pluggy.HookimplMarker("jac")

    class AnotherPlugin:
        @staticmethod
        @hookimpl
        def setup() -> str:
            return "I'm here"

    pm.register(AnotherPlugin())

    # Check that both implementations are detected
    assert len(pm.hook.setup.get_hookimpls()) == 1

    # Execute the hook and check both results are returned
    results = pm.hook.setup()
    assert "I'm here" in results
