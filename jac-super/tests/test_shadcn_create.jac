"""Tests that jac-shadcn registers as a non-default `fullstack` variant.

With the aggregating `register_project_template` hook, every plugin's templates
are collected: jac-client contributes the default `fullstack` template while
jac-super contributes `jac-shadcn` as a variant of the same kind. `--kind
fullstack` must select the plain template; `--use jac-shadcn` selects the
variant."""

import from jaclang.project.template_registry {
    get_template_registry,
    initialize_template_registry
}

test "jac-shadcn is a non-default fullstack variant" {
    initialize_template_registry();
    registry = get_template_registry();

    shadcn = registry.get("jac-shadcn");
    assert shadcn is not None , "jac-shadcn template should be registered";
    assert shadcn.kind == "fullstack";
    assert shadcn.is_default_for_kind == False;
}

test "--kind fullstack resolves to the default (non-shadcn) template" {
    initialize_template_registry();
    registry = get_template_registry();

    default_fs = registry.get_by_kind("fullstack");
    assert default_fs is not None , "a default fullstack template should exist";
    assert default_fs.is_default_for_kind == True;
    assert default_fs.name != "jac-shadcn";
}
