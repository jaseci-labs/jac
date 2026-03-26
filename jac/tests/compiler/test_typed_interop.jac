"""Tests for typed object passing across SV/CL codespace boundaries.

Validates that the compiler correctly handles typed objects crossing
the server/client boundary in all four data flows:
  1. SV -> CL function returns (typed objects returned to client)
  2. CL -> SV function args (typed objects sent as arguments)
  3. SV -> CL walker reports (typed nodes/objects in reports)
  4. CL -> SV walker fields (typed objects as walker has fields)

Tests with SkipTest document DESIRED behavior that will pass once
the boundary type manifest and hydration codegen are implemented.
"""

import os;
import unittest;
import tempfile;
import from pathlib { Path }
import from tempfile { NamedTemporaryFile, TemporaryDirectory }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "ecmascript", "fixtures"
     ),
     _test_tmp_dir: str = tempfile.mkdtemp(prefix="jac_test_typed_interop_");

def compile_fixture(name: str, prog: JacProgram | None = None) -> object {
    fixture = os.path.join(FIXTURE_DIR, name);
    if prog is None {
        prog = JacProgram();
    }
    return prog.compile(fixture);
}

def compile_inline(code: str, prog: JacProgram | None = None) -> object {
    with NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as f {
        f.write(code);
        f.flush();
        if prog is None {
            prog = JacProgram();
        }
        mod = prog.compile(f.name);
        os.unlink(f.name);
        return mod;
    }
}


# ============================================================================
# Group 1: All fixtures compile and generate correct RPC stubs
# ============================================================================

# Every typed interop fixture should compile to JS with the correct RPC mechanism
test "all typed fixtures compile with correct stubs" {
    function_fixtures = [
        "typed_return_obj.jac",
        "typed_return_obj_client.cl.jac",
        "typed_return_nested.jac",
        "typed_return_enum.jac",
        "typed_optional_union.jac",
        "typed_collection_return.jac",
        "typed_args_obj.jac",
        "typed_bidirectional.jac",
        "typed_bidirectional_client.cl.jac"
    ];
    spawn_fixtures = [
        "typed_walker_spawn.jac",
        "typed_walker_fields.jac",
        "typed_graph_return.jac"
    ];
    for name in function_fixtures {
        mod = compile_fixture(name);
        js = mod.gen.js;
        assert js.strip() , f"{name} should generate JavaScript";
        assert "__jacCallFunction" in js , f"{name} should have __jacCallFunction";
    }
    for name in spawn_fixtures {
        mod = compile_fixture(name);
        js = mod.gen.js;
        assert js.strip() , f"{name} should generate JavaScript";
        assert "__jacSpawn" in js , f"{name} should have __jacSpawn";
    }
}

# Existing non-typed fixtures still compile (regression guard)
test "existing fixtures still compile" {
    mod = compile_fixture("separated_client.cl.jac");
    assert "__jacSpawn" in mod.gen.js;
    mod = compile_fixture("separated_defpub_client.cl.jac");
    assert "__jacCallFunction" in mod.gen.js;
    mod = compile_fixture("mixed_cl_default.cl.jac");
    assert mod.gen.js.strip();
    mod = compile_fixture("mixed_sv_default.sv.jac");
    assert mod.gen.js.strip();
}

# Inline cl block with def:pub produces __jacCallFunction
test "inline cl block with defpub generates stubs" {
    code = '"""Test."""\n\ndef:pub get_data(name: str) -> dict {\n    return {"message": "Hello " + name};\n}\n\ncl {\n    def:pub app() -> Any {\n        data = await get_data("World");\n        return <div>{data}</div>;\n    }\n}\n';
    mod = compile_inline(code);
    js = mod.gen.js;
    assert "__jacCallFunction" in js;
    assert '"get_data"' in js or "'get_data'" in js;
}

# Endpoint effects correctly classify readers and writers
test "endpoint effects classify readers and writers" {
    code = '"""Test."""\n\nnode Item { has name: str; }\n\nwalker read_items {\n    can visit_root with Root entry { report [-->]; }\n}\n\nwalker add_item {\n    has name: str;\n    can do_add with Root entry { here ++> Item(name=self.name); }\n}\n\ndef:pub get_count() -> int { return 0; }\n\ndef:pub delete_all() -> None { items = []; del items; }\n\ncl {\n    def:pub app() {\n        root spawn read_items();\n        root spawn add_item(name="x");\n        c = await get_count();\n        await delete_all();\n    }\n}\n';
    mod = compile_inline(code);
    effects = mod.gen.client_manifest.endpoint_effects;
    assert "walker:read_items" in effects;
    assert not effects["walker:read_items"]["is_writer"];
    assert "walker:add_item" in effects;
    assert effects["walker:add_item"]["is_writer"];
    assert "func:get_count" in effects;
    assert not effects["func:get_count"]["is_writer"];
    assert "func:delete_all" in effects;
    assert effects["func:delete_all"]["is_writer"];
}

# Client manifest tracks exports from typed return fixture
test "client manifest tracks exports" {
    mod = compile_fixture("typed_return_obj.jac");
    manifest = mod.gen.client_manifest;
    assert "app" in manifest.exports;
}


# ============================================================================
# Group 2: SV -> CL hydration (typed returns)
# ============================================================================

# Plain obj return should generate JS class stub + hydration wrapper
test "hydration: plain obj return" {
    mod = compile_fixture("typed_return_obj.jac");
    js = mod.gen.js;
    assert "class Todo" in js , "Should emit JS class stub for Todo";
    assert "__from_wire" in js , "Should wrap return with hydration";
}

# Nested obj (Person.address: Address) should chain hydration recursively
test "hydration: nested obj return" {
    mod = compile_fixture("typed_return_nested.jac");
    js = mod.gen.js;
    assert "class Person" in js;
    assert "class Address" in js;
    assert "__from_wire" in js;
}

# Enum fields should be hydrated as proper enum instances
test "hydration: enum values preserved" {
    mod = compile_fixture("typed_return_enum.jac");
    js = mod.gen.js;
    assert "Priority" in js , "Should emit JS enum stub for Priority";
    assert "Status" in js , "Should emit JS enum stub for Status";
}

# Optional[T] should hydrate non-null and pass through null
test "hydration: optional handles null" {
    mod = compile_fixture("typed_optional_union.jac");
    js = mod.gen.js;
    assert "class UserProfile" in js;
    assert "__from_wire" in js;
}

# list[Obj] should hydrate each element individually
test "hydration: list elements individually hydrated" {
    mod = compile_fixture("typed_collection_return.jac");
    js = mod.gen.js;
    assert "class Metric" in js;
    assert "class Dashboard" in js;
}

# Walker reports containing typed nodes should be hydrated
test "hydration: walker reports as typed nodes" {
    mod = compile_fixture("typed_walker_spawn.jac");
    js = mod.gen.js;
    assert "class Project" in js or "__from_wire" in js;
}

# Nodes should be hydrated with _jac_id and graph identity
test "hydration: graph nodes preserve identity" {
    mod = compile_fixture("typed_graph_return.jac");
    js = mod.gen.js;
    assert "class Department" in js or "class Employee" in js;
    assert "__from_wire" in js;
}


# ============================================================================
# Group 3: CL -> SV serialization (typed args)
# ============================================================================

# Typed obj arguments should be serialized with __to_wire
test "serialization: obj argument uses to_wire" {
    mod = compile_fixture("typed_args_obj.jac");
    js = mod.gen.js;
    assert "__to_wire" in js;
}

# Typed objects in walker has fields should be serialized
test "serialization: walker has fields use to_wire" {
    mod = compile_fixture("typed_walker_fields.jac");
    js = mod.gen.js;
    assert "__to_wire" in js;
}

# Full round-trip: __to_wire on send AND __from_wire on receive
test "serialization: bidirectional round trip" {
    mod = compile_fixture("typed_bidirectional.jac");
    js = mod.gen.js;
    assert "class CartItem" in js;
    assert "class ShippingInfo" in js;
    assert "class OrderSummary" in js;
    assert "__to_wire" in js;
    assert "__from_wire" in js;
}


# ============================================================================
# Group 4: Boundary type manifest (compiler metadata)
# ============================================================================

# InteropManifest should collect boundary types with param + return types
test "manifest: boundary types with params and returns" {
    mod = compile_fixture("typed_bidirectional.jac");
    manifest = mod.gen.interop_manifest;
    exports = manifest.server_exports_to_client;
    func_names = [b.name for b in exports];
    assert "place_order" in func_names;
    for b in exports {
        if b.name == "place_order" {
            assert "OrderSummary" in b.ret_type;
            param_type_str = str(b.param_types);
            assert "CartItem" in param_type_str or "ShippingInfo" in param_type_str;
        }
    }
}

# Nested types (Person -> Address) should be transitively collected
test "manifest: nested types transitively collected" {
    mod = compile_fixture("typed_return_nested.jac");
    manifest = mod.gen.interop_manifest;
    exports = manifest.server_exports_to_client;
    func_names = [b.name for b in exports];
    assert "get_person" in func_names;
    for b in exports {
        if b.name == "get_person" {
            assert "Person" in b.ret_type;
        }
    }
}
