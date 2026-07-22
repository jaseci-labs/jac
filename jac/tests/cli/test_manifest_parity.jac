"""Freshness guard for the generated CLI manifest route table.

The ``_command_routes`` body in ``manifest.impl.jac`` is generated from the
``@registry.command`` decorators by ``jac gen-cli-manifest``. The
manifest/registry field-by-field agreement is therefore structural (the route
table is a projection of the decorators); what can drift is the committed block
going stale after a decorator edit without a matching regen. Budget, tombstone,
and tier policy are enforced at generation time. CI enforces freshness via
``jac gen-cli-manifest --verify``.
"""

import from jaclang.cli.gen_cli_manifest { verify_drift }


test "manifest route table is current" {
    drift = verify_drift();
    assert not drift , (
        "manifest.impl.jac route table is stale: the @registry.command decorators no "
        f"longer match the committed route table ({drift}). "
        "Run `jac gen-cli-manifest` to regenerate."
    );
}
