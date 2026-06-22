"""Tests that jac-shadcn registers as a non-default `fullstack` variant.

The default `fullstack` template ships in core and is registered directly by
`initialize_template_registry`; the `jac-shadcn` variant is contributed through
the aggregating `register_project_template` hook by the built-in shadcn
provider. `--kind fullstack` must select the plain template; `--use jac-shadcn`
selects the variant.

Core tests run with all non-runtime providers unregistered (see
jac/tests/conftest.py), so the first test re-registers the shadcn provider for
the duration of its assertions, then restores the disabled state.
"""

import from jaclang.jac0core.runtime { plugin_manager }
import from jaclang.cli.shadcn.plugin { JacShadcnPlugin }
import from jaclang.project.template_registry {
    get_template_registry,
    initialize_template_registry
}

test "jac-shadcn is a non-default fullstack variant" {
    re_registered = not plugin_manager.is_registered(JacShadcnPlugin);
    if re_registered {
        plugin_manager.register(JacShadcnPlugin);
    }
    try {
        initialize_template_registry();
        registry = get_template_registry();
        shadcn = registry.get("jac-shadcn");
        assert shadcn is not None , "jac-shadcn template should be registered";
        assert shadcn.kind == "fullstack";
        assert shadcn.is_default_for_kind == False;
    } finally {
        if re_registered {
            plugin_manager.unregister(plugin=JacShadcnPlugin);
        }
    }
}

test "--kind fullstack resolves to the default (non-shadcn) template" {
    initialize_template_registry();
    registry = get_template_registry();

    default_fs = registry.get_by_kind("fullstack");
    assert default_fs is not None , "a default fullstack template should exist";
    assert default_fs.is_default_for_kind == True;
    assert default_fs.name != "jac-shadcn";
}
