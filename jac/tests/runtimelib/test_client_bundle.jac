"""Tests for client bundle generation."""

import re;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

test "build bundle for module" {
    (module, ) = Jac.jac_import("client_app", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    assert "function __jacJsx" in bundle.code;
    # Check that registration mechanism is present
    assert "moduleFunctions[funcName] = funcRef;" in bundle.code;
    assert "scope[funcName] = funcRef;" in bundle.code;
    assert "moduleGlobals[gName] = existing;" in bundle.code;
    assert "scope[gName] = defaultValue;" in bundle.code;
    # Check that actual client functions and globals are defined
    assert "function client_page()" in bundle.code;
    assert "class ButtonProps" in bundle.code;
    assert 'let API_LABEL = "Runtime Test";' in bundle.code;
    # Check hydration logic is present
    assert "__jacHydrateFromDom" in bundle.code;
    assert "__jacEnsureHydration" in bundle.code;
    assert 'getElementById("__jac_init__")' in bundle.code;
    assert 'getElementById("__jac_root")' in bundle.code;
    # Check globals iteration logic
    assert "for (const gName of __objectKeys(payloadGlobals))" in bundle.code;
    assert "client_page" in bundle.client_functions;
    assert "ButtonProps" in bundle.client_functions;
    assert "API_LABEL" in bundle.client_globals;
    assert len(bundle.hash) > 10;

    cached = builder.build(module);
    assert bundle.hash == cached.hash;
    assert bundle.code == cached.code;
}

test "build bundle with cl import" {
    (module, ) = Jac.jac_import("client_app_with_import", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Check that client_runtime functions are included in the bundle
    assert "function renderJsxTree" in bundle.code;
    assert "function jacLogin" in bundle.code;

    # Check that our client code is present
    assert "function test_page()" in bundle.code;
    assert 'let APP_TITLE = "Import Test App";' in bundle.code;

    # Verify the @jac/runtime comment is present (inlined by bundler)
    assert "// @jac/runtime" in bundle.code;

    # IMPORTANT: Ensure no ES6 import statements are in the bundle
    assert "import {" not in bundle.code;
    assert 'from "@jac/runtime"' not in bundle.code;

    # Check that client functions are registered
    assert "test_page" in bundle.client_functions;
    assert "APP_TITLE" in bundle.client_globals;

    # Ensure the bundle has a valid hash
    assert len(bundle.hash) > 10;
}

test "build bundle with relative import" {
    (module, ) = Jac.jac_import("client_app_with_relative_import", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Check that the imported module is included
    assert "// Imported .jac module: .client_ui_components" in bundle.code;
    assert "function Button(" in bundle.code;
    assert "function Card(" in bundle.code;
    assert "function handleClick(" in bundle.code;

    # Check that main_page is present
    assert "function main_page()" in bundle.code;

    # Check that transitive imports are included
    assert "// Imported .jac module: @jac/runtime" in bundle.code;
    assert "function createState(" in bundle.code;
    assert "function navigate(" in bundle.code;

    # IMPORTANT: Ensure NO import statements remain
    assert "import {" not in bundle.code;
    assert "from './" not in bundle.code;
    assert 'from "./' not in bundle.code;

    # Check that all modules are bundled in the correct order
    client_runtime_pos = bundle.code.find("// Imported .jac module: @jac/runtime");
    ui_components_pos = bundle.code.find(
        "// Imported .jac module: .client_ui_components"
    );
    main_page_pos = bundle.code.find("function main_page()");

    assert ui_components_pos > client_runtime_pos;
    assert main_page_pos > ui_components_pos;

    # Verify client functions are registered
    assert "main_page" in bundle.client_functions;
}

test "no import statements in bundle" {
    (module, ) = Jac.jac_import("client_app_with_relative_import", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Split bundle into lines and check for any import statements
    lines = bundle.code.split("\n");
    import_lines = [
        line
        for line in lines
        if line.strip().startswith("import ") and " from " in line
    ];

    # Should be exactly 0 import statements
    assert len(import_lines) == 0 , f"Found {len(import_lines)} import statement(s) in bundle: {import_lines[:3]}";

    # Also verify using regex pattern
    import_pattern = r'^\s*import\s+.*\s+from\s+["\'].*["\'];?\s*$';
    import_matches = [
        line
        for line in lines
        if re.match(import_pattern, line)
    ];
    assert len(import_matches) == 0 , f"Found import statements matching pattern: {import_matches[:3]}";
}

test "transitive imports included" {
    (module, ) = Jac.jac_import("client_app_with_relative_import", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Check that all three modules are present
    assert "// Imported .jac module: @jac/runtime" in bundle.code;
    assert "// Imported .jac module: .client_ui_components" in bundle.code;

    # Verify runtime functions are defined
    assert "function createState(" in bundle.code;
    assert "function navigate(" in bundle.code;

    # Verify that createState is actually callable (definition before usage)
    create_state_def_pos = bundle.code.find("function createState(");
    create_state_usage_pos = bundle.code.find("createState(");
    assert create_state_def_pos < create_state_usage_pos , "createState must be defined before it's used";
}

test "bundle size reasonable" {
    # Simple module without imports
    (simple_module, ) = Jac.jac_import("client_app", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    simple_bundle = builder.build(simple_module);

    # Module with imports
    (import_module, ) = Jac.jac_import("client_app_with_relative_import", FIXTURES);
    import_bundle = builder.build(import_module);

    # Bundle with imports should be larger
    assert len(import_bundle.code) > len(simple_bundle.code) , "Bundle with imports should be larger than simple bundle";

    # But not unreasonably large (should be less than 10x)
    assert len(import_bundle.code) < len(simple_bundle.code) * 10 , "Bundle should not be unreasonably large";
}

test "import path conversion" {
    import from jaclang.jac0core.modresolver { convert_to_js_import_path }

    # Test single dot (current directory)
    assert convert_to_js_import_path(".module") == "./module.js";

    # Test double dot (parent directory)
    assert convert_to_js_import_path("..module") == "../module.js";

    # Test triple dot (grandparent directory)
    assert convert_to_js_import_path("...module") == "../../module.js";

    # Test absolute import (no dots)
    assert convert_to_js_import_path("module") == "module";
}

test "cl block functions exported" {
    (module, ) = Jac.jac_import("client_ui_components", FIXTURES);
    builder = Jac.get_client_bundle_builder();
    bundle = builder.build(module);

    # Functions defined inside cl block should be in client_functions
    assert "Button" in bundle.client_functions;
    assert "Card" in bundle.client_functions;
    assert "handleClick" in bundle.client_functions;

    # Check that functions are actually defined in the bundle
    assert "function Button(" in bundle.code;
    assert "function Card(" in bundle.code;
    assert "function handleClick(" in bundle.code;
}

test "bundle caching with imports" {
    (module, ) = Jac.jac_import("client_app_with_relative_import", FIXTURES);
    builder = Jac.get_client_bundle_builder();

    # Build bundle first time
    bundle1 = builder.build(module);

    # Build bundle second time (should use cache)
    bundle2 = builder.build(module);

    # Should be identical
    assert bundle1.hash == bundle2.hash;
    assert bundle1.code == bundle2.code;
    assert bundle1.client_functions == bundle2.client_functions;

    # Force rebuild
    bundle3 = builder.build(module, force=True);

    # Should still be identical
    assert bundle1.hash == bundle3.hash;
    assert bundle1.code == bundle3.code;
}
