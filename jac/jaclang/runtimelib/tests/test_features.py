"""Tests for Jac parser."""

import inspect
from typing import List, Type

from jaclang.runtimelib.machine import (
    JacMachineInterface,
    JacMachineImpl,
    JacMachineSpec,
)
from jaclang.utils.test import TestCase

import pluggy


class TestFeatures(TestCase):
    """Test Jac self.prse."""

    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()

    def get_methods(self, cls: Type) -> List[str]:
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

    def test_feature_funcs_synced(self) -> None:
        """Test if JacMachine, JacMachineDefaults, and JacMachineSpec have synced methods."""
        # Get methods of each class
        jac_feature_methods = self.get_methods(JacMachineInterface)
        jac_feature_defaults_methods = self.get_methods(JacMachineImpl)
        jac_feature_spec_methods = self.get_methods(JacMachineSpec)

        # Check if all methods are the same in all classes
        self.assertGreater(len(jac_feature_methods), 5)
        self.assertEqual(jac_feature_spec_methods, jac_feature_defaults_methods)
        for i in jac_feature_spec_methods:
            self.assertIn(i, jac_feature_methods)

    def test_multiple_plugins(self) -> None:
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
        self.assertEqual(len(pm.hook.setup.get_hookimpls()), 1)

        # Execute the hook and check both results are returned
        results = pm.hook.setup()
        self.assertIn("I'm here", results)
