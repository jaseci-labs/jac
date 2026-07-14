"""Tests that jac-shadcn registers as a non-default `web-app` variant.

The default `web-app` template ships in core and is registered directly by
`initialize_template_registry`; the `jac-shadcn` variant is contributed by the
built-in shadcn provider, which `initialize_template_registry` invokes directly.
`--kind web-app` must select the plain template; `--use jac-shadcn` selects the
variant.
"""

import from jaclang.project.template_registry {
    get_template_registry,
    initialize_template_registry
}

test "jac-shadcn is a non-default web-app variant" {
    initialize_template_registry();
    registry = get_template_registry();
    shadcn = registry.get("jac-shadcn");
    assert shadcn is not None , "jac-shadcn template should be registered";
    assert shadcn.kind == "web-app";
    assert shadcn.is_default_for_kind == False;
}

test "--kind web-app resolves to the default (non-shadcn) template" {
    initialize_template_registry();
    registry = get_template_registry();

    default_fs = registry.get_by_kind("web-app");
    assert default_fs is not None , "a default web-app template should exist";
    assert default_fs.is_default_for_kind == True;
    assert default_fs.name != "jac-shadcn";
}
