"""Tests for typed RPC emission — JacClient.kt from InteropManifest."""
import from jaclang.compiler.passes.compose.rpc_client { emit_jac_client }
import from jaclang.jac0core.codeinfo { BoundaryTypeInfo, InteropManifest }

test "emit_jac_client includes request fields from boundary_types" {
    manifest = InteropManifest();
    manifest.walker_access = {"greet": False};
    manifest.boundary_types = {
        "GreetRequest": BoundaryTypeInfo(
            name="GreetRequest",
            kind="walker",
            fields=[("name", "str")],
            field_defaults={"name": "friend"}
        ),
        "GreetResponse": BoundaryTypeInfo(
            name="GreetResponse",
            kind="obj",
            fields=[("reports", "list[str]")],
            field_defaults={"reports": []}
        )
    };
    code = emit_jac_client("dev.jac.test", manifest);
    assert "@Serializable" in code;
    assert "data class GreetRequest" in code;
    assert "val name: String" in code;
    assert 'suspend fun greet(req: GreetRequest' in code;
}

test "renamed walker field changes generated GreetRequest" {
    manifest_old = InteropManifest();
    manifest_old.walker_access = {"greet": False};
    manifest_old.boundary_types = {
        "GreetRequest": BoundaryTypeInfo(
            name="GreetRequest",
            kind="walker",
            fields=[("name", "str")],
            field_defaults={"name": "friend"}
        ),
        "GreetResponse": BoundaryTypeInfo(
            name="GreetResponse",
            kind="obj",
            fields=[("reports", "list[str]")],
            field_defaults={"reports": []}
        )
    };
    manifest_new = InteropManifest();
    manifest_new.walker_access = {"greet": False};
    manifest_new.boundary_types = {
        "GreetRequest": BoundaryTypeInfo(
            name="GreetRequest",
            kind="walker",
            fields=[("username", "str")],
            field_defaults={"username": "friend"}
        ),
        "GreetResponse": BoundaryTypeInfo(
            name="GreetResponse",
            kind="obj",
            fields=[("reports", "list[str]")],
            field_defaults={"reports": []}
        )
    };
    old_code = emit_jac_client("dev.jac.test", manifest_old);
    new_code = emit_jac_client("dev.jac.test", manifest_new);
    assert "val name: String" in old_code;
    assert "val username: String" in new_code;
    assert "val name: String" not in new_code;
    assert "val username: String" not in old_code;
}
