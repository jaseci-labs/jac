"""HMR (Hot Module Replacement) tests using JacTestClient.

These tests verify HMR functionality without starting real servers.
The reload() method simulates what happens when a file changes.
"""

import uuid;
import from contextlib { suppress }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.runtimelib.hmr { HotReloader }
import from jaclang.runtimelib.testing { JacTestClient }
import from jaclang.runtimelib.watcher { JacFileWatcher }

# --- TestHMRWalkerReload ---
test "walker code reloads after file change" {
    with TemporaryDirectory() as tmpdir {
        temp_project = Path(tmpdir);
        app_file = temp_project / "app.jac";
        # Version 1: walker returns value 1
        app_file.write_text(
            "walker get_value {\n"
            "    can enter with Root entry {\n"
            '        report {"value": 1};\n'
            "    }\n"
            "}\n"
        );
        client = JacTestClient.from_file(str(app_file), base_path=str(temp_project));
        try {
            # Register user for authenticated requests
            client.register_user("testuser", "password123");

            # Call walker - should return 1
            response1 = client.post("/walker/get_value", json={});
            assert response1.ok;
            reports1 = response1.data.get("reports", []);
            assert len(reports1) > 0;
            assert reports1[0].get("value") == 1;

            # Version 2: update walker to return value 2
            app_file.write_text(
                "walker get_value {\n"
                "    can enter with Root entry {\n"
                '        report {"value": 2};\n'
                "    }\n"
                "}\n"
            );

            # Trigger reload
            client.reload();

            # Call walker again - should now return 2
            response2 = client.post("/walker/get_value", json={});
            assert response2.ok;
            reports2 = response2.data.get("reports", []);
            assert len(reports2) > 0;
            assert reports2[0].get("value") == 2;

            # Verify the value actually changed
            assert reports1[0].get("value") != reports2[0].get("value");
        } finally {
            client.close();
        }
    }
}

test "global variable reloads" {
    with TemporaryDirectory() as tmpdir {
        temp_project = Path(tmpdir);
        app_file = temp_project / "glob_var.jac";
        # Version 1
        app_file.write_text(
            "glob VERSION = 1;\n"
            "\n"
            "walker get_version {\n"
            "    can enter with Root entry {\n"
            '        report {"version": VERSION};\n'
            "    }\n"
            "}\n"
        );
        client = JacTestClient.from_file(str(app_file), base_path=str(temp_project));
        try {
            client.register_user("testuser", "password123");

            # Get version 1
            response1 = client.post("/walker/get_version", json={});
            assert response1.ok;
            v1 = response1.data.get("reports", [{}])[0].get("version");
            assert v1 == 1;

            # Version 2
            app_file.write_text(
                "glob VERSION = 2;\n"
                "\n"
                "walker get_version {\n"
                "    can enter with Root entry {\n"
                '        report {"version": VERSION};\n'
                "    }\n"
                "}\n"
            );

            client.reload();

            # Get version 2
            response2 = client.post("/walker/get_version", json={});
            assert response2.ok;
            v2 = response2.data.get("reports", [{}])[0].get("version");
            assert v2 == 2;
        } finally {
            client.close();
        }
    }
}

test "new walker available after reload" {
    with TemporaryDirectory() as tmpdir {
        temp_project = Path(tmpdir);
        app_file = temp_project / "walker.jac";
        # Version 1: only one walker
        app_file.write_text(
            "walker walker_one {\n"
            "    can enter with Root entry {\n"
            '        report {"name": "one"};\n'
            "    }\n"
            "}\n"
        );
        client = JacTestClient.from_file(str(app_file), base_path=str(temp_project));
        try {
            client.register_user("testuser", "password123");

            # walker_one should work
            response1 = client.post("/walker/walker_one", json={});
            assert response1.ok;

            # walker_two should not exist
            response2 = client.post("/walker/walker_two", json={});
            assert not response2.ok or "error" in str(response2.data);

            # Version 2: add walker_two
            app_file.write_text(
                "walker walker_one {\n"
                "    can enter with Root entry {\n"
                '        report {"name": "one"};\n'
                "    }\n"
                "}\n"
                "\n"
                "walker walker_two {\n"
                "    can enter with Root entry {\n"
                '        report {"name": "two"};\n'
                "    }\n"
                "}\n"
            );

            client.reload();

            # Both walkers should now work
            response3 = client.post("/walker/walker_one", json={});
            assert response3.ok;

            response4 = client.post("/walker/walker_two", json={});
            assert response4.ok;
            assert response4.data.get("reports", [{}])[0].get("name") == "two";
        } finally {
            client.close();
        }
    }
}

# --- TestHMRMultipleReloads ---
test "multiple rapid reloads" {
    with TemporaryDirectory() as tmpdir {
        temp_project = Path(tmpdir);
        app_file = temp_project / "multi_ops.jac";
        app_file.write_text(
            "glob COUNTER = 0;\n"
            "\n"
            "walker get_counter {\n"
            "    can enter with Root entry {\n"
            '        report {"counter": COUNTER};\n'
            "    }\n"
            "}\n"
        );
        client = JacTestClient.from_file(str(app_file), base_path=str(temp_project));
        try {
            client.register_user("testuser", "password123");

            # Perform multiple reloads with different values
            for i in range(1, 6) {
                app_file.write_text(
                    f"glob COUNTER = {i};\n"
                    "\n"
                    "walker get_counter {\n"
                    "    can enter with Root entry {\n"
                    '        report {"counter": COUNTER};\n'
                    "    }\n"
                    "}\n"
                );

                client.reload();

                response = client.post("/walker/get_counter", json={});
                assert response.ok;
                counter = response.data.get("reports", [{}])[0].get("counter");
                assert counter == i , f"Expected counter={i}, got {counter}";
            }
        } finally {
            client.close();
        }
    }
}

# --- TestHMRFunctionReload ---
test "function code reloads" {
    with TemporaryDirectory() as tmpdir {
        temp_project = Path(tmpdir);
        app_file = temp_project / "function.jac";
        # Version 1
        app_file.write_text(
            "def get_message() -> str {\n" '    return "Hello Version 1";\n' "}\n"
        );
        client = JacTestClient.from_file(str(app_file), base_path=str(temp_project));
        try {
            client.register_user("testuser", "password123");

            # Call function
            response1 = client.post("/function/get_message", json={});
            assert response1.ok;
            result1 = response1.data.get("result");
            assert "Version 1" in result1;

            # Version 2
            app_file.write_text(
                "def get_message() -> str {\n" '    return "Hello Version 2";\n' "}\n"
            );

            client.reload();

            response2 = client.post("/function/get_message", json={});
            assert response2.ok;
            result2 = response2.data.get("result");
            assert "Version 2" in result2;
        } finally {
            client.close();
        }
    }
}

# --- TestHMRStatePreservation ---
test "auth token preserved after reload" {
    with TemporaryDirectory() as tmpdir {
        temp_project = Path(tmpdir);
        app_file = temp_project / "auth.jac";
        app_file.write_text(
            "walker get_status {\n"
            "    can check with Root entry {\n"
            '        report {"status": "v1"};\n'
            "    }\n"
            "}\n"
        );
        client = JacTestClient.from_file(str(app_file), base_path=str(temp_project));
        try {
            client.register_user("testuser", "password123");

            # Verify auth works
            resp1 = client.post("/walker/get_status", json={});
            assert resp1.ok;
            assert resp1.data.get("reports", [{}])[0].get("status") == "v1";

            # Reload module
            app_file.write_text(
                "walker get_status {\n"
                "    can check with Root entry {\n"
                '        report {"status": "v2"};\n'
                "    }\n"
                "}\n"
            );
            client.reload();

            # Auth should still work (token preserved in client)
            resp2 = client.post("/walker/get_status", json={});
            assert resp2.ok , "Auth failed after reload";
            assert resp2.data.get("reports", [{}])[0].get("status") == "v2" , "Code change not applied after reload";
        } finally {
            client.close();
        }
    }
}

test "user isolation without reload" {
    with TemporaryDirectory() as tmpdir {
        temp_project = Path(tmpdir);
        app_file = temp_project / "user.jac";
        app_file.write_text(
            "node Secret {\n"
            "    has data: str;\n"
            "}\n"
            "\n"
            "walker store_secret {\n"
            "    has data: str;\n"
            "    can store with Root entry {\n"
            "        here ++> Secret(data=self.data);\n"
            '        report {"stored": self.data};\n'
            "    }\n"
            "}\n"
            "\n"
            "walker get_secrets {\n"
            "    can collect with Root entry {\n"
            "        visit [-->];\n"
            "    }\n"
            "    can gather with Secret entry {\n"
            '        report {"data": here.data};\n'
            "    }\n"
            "}\n"
        );
        client = JacTestClient.from_file(str(app_file), base_path=str(temp_project));
        try {
            # User A stores a secret
            client.register_user("userA", "passA");
            resp1 = client.post("/walker/store_secret", json={"data": "A's secret"});
            assert resp1.ok;

            # User B stores a different secret
            client.clear_auth();
            client.register_user("userB", "passB");
            resp2 = client.post("/walker/store_secret", json={"data": "B's secret"});
            assert resp2.ok;

            # User B should only see their own secret
            resp3 = client.post("/walker/get_secrets", json={});
            assert resp3.ok;
            secrets_b = [r.get("data") for r in resp3.data.get("reports", [])];
            assert "B's secret" in secrets_b , "User B can't see their own data";
            assert "A's secret" not in secrets_b , "User isolation broken: B can see A's data";

            # User A should only see their own secret
            client.login("userA", "passA");
            resp4 = client.post("/walker/get_secrets", json={});
            assert resp4.ok;
            secrets_a = [r.get("data") for r in resp4.data.get("reports", [])];
            assert "A's secret" in secrets_a , "User A can't see their own data";
            assert "B's secret" not in secrets_a , "User isolation broken: A can see B's data";
        } finally {
            client.close();
        }
    }
}

# --- TestHMRErrorHandling ---
test "recovery from syntax error" {
    with TemporaryDirectory() as tmpdir {
        temp_project = Path(tmpdir);
        app_file = temp_project / "syn_error.jac";
        app_file.write_text(
            "walker get_value {\n"
            "    can check with Root entry {\n"
            '        report {"value": 1};\n'
            "    }\n"
            "}\n"
        );
        client = JacTestClient.from_file(str(app_file), base_path=str(temp_project));
        try {
            client.register_user("testuser", "password123");

            # Verify initial code works
            resp1 = client.post("/walker/get_value", json={});
            assert resp1.ok;
            assert resp1.data.get("reports", [{}])[0].get("value") == 1;

            # Introduce syntax error
            app_file.write_text(
                "walker get_value {\n"
                "    can check with Root entry {\n"
                "        # SYNTAX ERROR - missing closing brace\n"
                '        report {"value": 2};\n'
                "}\n"
            );

            # Reload should handle error gracefully (not crash)
            with suppress(Exception) {
                client.reload();
            }

            # The app entry is never used as an error billboard
            entry_file = temp_project / ".jac" / "client" / "compiled" / "_entry.js";
            if entry_file.exists() {
                assert "errorOverlay" not in entry_file.read_text() , "_entry.js must not be overwritten with an error overlay";
            }

            # Fix the syntax error with new value
            app_file.write_text(
                "walker get_value {\n"
                "    can check with Root entry {\n"
                '        report {"value": 3};\n'
                "    }\n"
                "}\n"
            );

            # Reload with fixed code
            client.reload();

            # Should work with fixed code
            resp2 = client.post("/walker/get_value", json={});
            assert resp2.ok;
            assert resp2.data.get("reports", [{}])[0].get("value") == 3 , "Code not updated after recovery from syntax error";
        } finally {
            client.close();
        }
    }
}

test "reload with code change preserves functionality" {
    with TemporaryDirectory() as tmpdir {
        temp_project = Path(tmpdir);
        app_file = temp_project / "rel_function.jac";
        # Version 1: multiply by 2
        app_file.write_text(
            "def compute(x: int) -> int {\n" "    return x * 2;\n" "}\n"
        );
        client = JacTestClient.from_file(str(app_file), base_path=str(temp_project));
        try {
            client.register_user("testuser", "password123");

            # Test v1 logic
            resp1 = client.post("/function/compute", json={"x": 5});
            assert resp1.ok;
            assert resp1.data.get("result") == 10;  # 5 * 2

            # Version 2: multiply by 3
            app_file.write_text(
                "def compute(x: int) -> int {\n" "    return x * 3;\n" "}\n"
            );

            client.reload();

            # Test v2 logic - should now multiply by 3
            resp2 = client.post("/function/compute", json={"x": 5});
            assert resp2.ok;
            assert resp2.data.get("result") == 15 , f"Expected 15 (5*3), got {resp2.data.get(  # 5 * 3
                'result'
            )} - code change not applied";
        } finally {
            client.close();
        }
    }
}

# --- TestHMRClientCodeRecompilation ---

# NOTE: test "client JS file updated on change" is commented out because it was
# marked with @pytest.mark.xfail in the Python version due to HotReloader having
# a global state issue causing cross-test contamination.
#
# test "client JS file updated on change" {
#     ...
# }
test "jacjsx import added in real compilation" {
    with TemporaryDirectory() as tmpdir {
        unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        unique_dir.mkdir(parents=True, exist_ok=True);
        compiled_dir = unique_dir / ".jac" / "client" / "compiled";
        compiled_dir.mkdir(parents=True, exist_ok=True);
        app_file = unique_dir / "app.jac";
        app_file.write_text(
            "cl {\n"
            "    def app() {\n"
            "        return <div>Hello</div>;\n"
            "    }\n"
            "}\n"
        );
        watcher = JacFileWatcher(watch_paths=[str(unique_dir)], _debounce_ms=50);
        reloader = HotReloader(
            base_path=str(unique_dir), module_name="app", watcher=watcher
        );
        reloader._recompile_client_code(str(app_file));
        output_file = unique_dir / ".jac" / "client" / "compiled" / "app.js";
        assert output_file.exists() , "JS file was not created";
        content = output_file.read_text();
        # JSX code should compile to use __jacJsx
        assert "__jacJsx" in content , "Compiled JS should contain __jacJsx for JSX elements";
        assert "import {__jacJsx" in content or "import{__jacJsx" in content , "__jacJsx is used but import statement is missing";
        # --- build error: reported out-of-band, never via _entry.js ---
        entry_file = unique_dir / ".jac" / "client" / "compiled" / "_entry.js";
        error_file = unique_dir / ".jac" / "client" / ".jac-build-error.json";
        bad_file = unique_dir / "app.jac";
        bad_file.write_text(
            "cl {\n"
            "    def app() {\n"
            "        return <div UNCLOSED;\n"  # malformed JSX / syntax error
            "    }\n"
            "}\n"
        );
        reloader._recompile_client_code(str(bad_file));
        assert not entry_file.exists() , "_entry.js must not be created just to display an error";
        assert error_file.exists() , "build error must be mirrored to .jac-build-error.json for the Vite overlay";
        import json;
        error_data = json.loads(error_file.read_text());
        assert error_data["message"] , "mirrored build error must carry a non-empty message";
        assert "app.jac" in str(error_data["message"]) , "mirrored error must reference the failing source location";
        assert reloader.build_status()["status"] == "error";
        # --- fix the error: recovery clears the mirrored error ---
        bad_file.write_text(
            "cl {\n"
            "    def app() {\n"
            "        return <div>Fixed</div>;\n"
            "    }\n"
            "}\n"
        );
        reloader._recompile_client_code(str(bad_file));
        reloader.record_ok();  # _process_change settles to ok after a clean rebuild
        assert not error_file.exists() , ".jac-build-error.json must be removed on recovery";
        assert reloader.build_status()["status"] == "ok";
    }
}

test "client recompile preserves directory structure" {
    with TemporaryDirectory() as tmpdir {
        unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        unique_dir.mkdir(parents=True, exist_ok=True);
        compiled_dir = unique_dir / ".jac" / "client" / "compiled";
        compiled_dir.mkdir(parents=True, exist_ok=True);
        # Create a nested components directory
        components_dir = unique_dir / "components";
        components_dir.mkdir(parents=True, exist_ok=True);
        # Create a component file in the subdirectory
        component_file = components_dir / "Button.cl.jac";
        component_file.write_text(
            "cl {\n"
            "    def Button() {\n"
            "        return <button>Click me</button>;\n"
            "    }\n"
            "}\n"
        );
        watcher = JacFileWatcher(watch_paths=[str(unique_dir)], _debounce_ms=50);
        reloader = HotReloader(
            base_path=str(unique_dir), module_name="app", watcher=watcher
        );
        reloader._recompile_client_code(str(component_file));
        # The output should preserve the components/ subdirectory
        correct_output = (
            unique_dir / ".jac" / "client" / "compiled" / "components" / "Button.js"
        );
        wrong_output = unique_dir / ".jac" / "client" / "compiled" / "Button.js";
        assert correct_output.exists() , f"Expected output at {correct_output}, but file not found. "
        "Directory structure not preserved.";
        assert not wrong_output.exists() , f"File incorrectly written to {wrong_output} instead of {correct_output}";
    }
}

# --- TestHMRAssetServing ---
test "image asset copied on add" {
    with TemporaryDirectory() as tmpdir {
        unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        unique_dir.mkdir(parents=True, exist_ok=True);
        assets_dir = unique_dir / "assets";
        assets_dir.mkdir(parents=True, exist_ok=True);
        compiled_dir = unique_dir / ".jac" / "client" / "compiled";
        compiled_dir.mkdir(parents=True, exist_ok=True);
        # Create a sample image file (mock as a small binary file)
        image_file = assets_dir / "logo.png";
        image_content = b"fake_png_data";
        image_file.write_bytes(image_content);
        watcher = JacFileWatcher(watch_paths=[str(unique_dir)], _debounce_ms=50);
        reloader = HotReloader(
            base_path=str(unique_dir), module_name="app", watcher=watcher
        );
        reloader._copy_frontend_files(str(image_file));
        output_file = (
            unique_dir / ".jac" / "client" / "compiled" / "assets" / "logo.png"
        );
        assert output_file.exists() , "Asset file was not copied to compiled directory";
        assert output_file.read_bytes() == image_content , "Asset content does not match";
    }
}

test "image asset deleted when source deleted" {
    with TemporaryDirectory() as tmpdir {
        unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        unique_dir.mkdir(parents=True, exist_ok=True);
        assets_dir = unique_dir / "assets";
        assets_dir.mkdir(parents=True, exist_ok=True);
        compiled_dir = unique_dir / ".jac" / "client" / "compiled";
        compiled_dir.mkdir(parents=True, exist_ok=True);
        image_file = assets_dir / "logo.png";
        image_content = b"fake_png_data";
        image_file.write_bytes(image_content);
        watcher = JacFileWatcher(watch_paths=[str(unique_dir)], _debounce_ms=50);
        reloader = HotReloader(
            base_path=str(unique_dir), module_name="app", watcher=watcher
        );
        reloader._copy_frontend_files(str(image_file));
        output_file = (
            unique_dir / ".jac" / "client" / "compiled" / "assets" / "logo.png"
        );
        assert output_file.exists() , "Asset file was not copied to compiled directory";
        image_file.unlink();
        reloader._copy_frontend_files(str(image_file));
        assert not output_file.exists() , "Compiled asset was not deleted when source was deleted";
    }
}

test "tsx component copied and updated on change" {
    with TemporaryDirectory() as tmpdir {
        unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        unique_dir.mkdir(parents=True, exist_ok=True);
        assets_dir = unique_dir / "assets";
        assets_dir.mkdir(parents=True, exist_ok=True);
        compiled_dir = unique_dir / ".jac" / "client" / "compiled";
        compiled_dir.mkdir(parents=True, exist_ok=True);
        components_dir = unique_dir / "components";
        components_dir.mkdir(parents=True, exist_ok=True);
        tsx_file = components_dir / "Button.tsx";
        initial_content = (
            "import React from 'react';\n"
            "\n"
            "interface ButtonProps {\n"
            "  children: React.ReactNode;\n"
            "  onClick?: () => void;\n"
            "}\n"
            "\n"
            "const Button: React.FC<ButtonProps> = ({ children, onClick }) => {\n"
            "  return (\n"
            '    <button onClick={onClick} className="btn">\n'
            "      {children}\n"
            "    </button>\n"
            "  );\n"
            "};\n"
            "\n"
            "export default Button;\n"
        );
        tsx_file.write_text(initial_content);
        watcher = JacFileWatcher(watch_paths=[str(unique_dir)], _debounce_ms=50);
        reloader = HotReloader(
            base_path=str(unique_dir), module_name="app", watcher=watcher
        );
        reloader._copy_frontend_files(str(tsx_file));
        output_file = (
            unique_dir / ".jac" / "client" / "compiled" / "components" / "Button.tsx"
        );
        assert output_file.exists() , "TSX component file was not copied to compiled directory";
        assert output_file.read_text() == initial_content , "TSX component content does not match";
        # Modify the .tsx file content
        updated_content = (
            "import React from 'react';\n"
            "\n"
            "interface ButtonProps {\n"
            "  children: React.ReactNode;\n"
            "  onClick?: () => void;\n"
            "  variant?: 'primary' | 'secondary';\n"
            "}\n"
            "\n"
            "const Button: React.FC<ButtonProps> = ({ children, onClick, variant = 'primary' }) => {\n"
            "  return (\n"
            "    <button onClick={onClick} className={`btn btn-${variant}`}>\n"
            "      {children}\n"
            "    </button>\n"
            "  );\n"
            "};\n"
            "\n"
            "export default Button;\n"
        );
        tsx_file.write_text(updated_content);
        reloader._copy_frontend_files(str(tsx_file));
        assert output_file.exists() , "TSX component file should still exist after update";
        assert output_file.read_text() == updated_content , "TSX component content was not updated in compiled directory";
    }
}

# --- TestHMRImplFileReload ---
"""Test that changing a .impl.jac file triggers reload of its base .jac file."""
test "server impl file reloads base jac file" {
    with TemporaryDirectory() as tmpdir {
        temp_project = Path(tmpdir);
        # Create base server-side .jac file with abstract method
        base_file = temp_project / "calculator.jac";
        base_file.write_text(
            "obj Calculator {\n"
            "    def add(a: int, b: int) -> int;\n"
            "}\n"
            "\n"
            "walker calculate {\n"
            "    has x: int = 5, y: int = 3;\n"
            "    can compute with Root entry {\n"
            "        calc = Calculator();\n"
            "        result = calc.add(self.x, self.y);\n"
            '        report {"result": result};\n'
            "    }\n"
            "}\n"
        );
        # Create .impl.jac file - Version 1
        impl_file = temp_project / "calculator.impl.jac";
        impl_file.write_text(
            "impl Calculator.add(a: int, b: int) -> int {\n"
            "    return a + b;  # Simple addition\n"
            "}\n"
        );
        client = JacTestClient.from_file(str(base_file), base_path=str(temp_project));
        try {
            client.register_user("testuser", "password123");

            # Call walker - should return 8 (5 + 3)
            response1 = client.post("/walker/calculate", json={});
            assert response1.ok;
            reports1 = response1.data.get("reports", []);
            assert len(reports1) > 0;
            assert reports1[0].get("result") == 8;

            # Version 2: Update impl file to multiply
            impl_file.write_text(
                "impl Calculator.add(a: int, b: int) -> int {\n"
                "    return a * b;  # Now multiply instead\n"
                "}\n"
            );

            # Trigger reload
            client.reload();

            # Call walker again - should now return 15 (5 * 3)
            response2 = client.post("/walker/calculate", json={});
            assert response2.ok;
            reports2 = response2.data.get("reports", []);
            assert len(reports2) > 0;
            assert reports2[0].get("result") == 15;

            # Verify the value actually changed
            assert reports1[0].get("result") != reports2[0].get("result");
        } finally {
            client.close();
        }
    }
}

"""Test that changing a .impl.jac file triggers recompilation of its base .cl.jac file."""
test "client impl file reloads base cl.jac file" {
    with TemporaryDirectory() as tmpdir {
        unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        unique_dir.mkdir(parents=True, exist_ok=True);
        compiled_dir = unique_dir / ".jac" / "client" / "compiled";
        compiled_dir.mkdir(parents=True, exist_ok=True);
        # Create base client-side .cl.jac file
        base_file = unique_dir / "Button.cl.jac";
        base_file.write_text(
            "cl {\n"
            "    obj ButtonProps {\n"
            "        def get_label() -> str;\n"
            "    }\n"
            "\n"
            "    def Button(props: ButtonProps) {\n"
            "        label = props.get_label();\n"
            "        return <button>{label}</button>;\n"
            "    }\n"
            "}\n"
        );
        # Create .impl.jac file - Version 1
        impl_file = unique_dir / "Button.impl.jac";
        impl_file.write_text(
            "cl {\n"
            "    impl ButtonProps.get_label() -> str {\n"
            '        return "Click Me";\n'
            "    }\n"
            "}\n"
        );
        watcher = JacFileWatcher(watch_paths=[str(unique_dir)], _debounce_ms=50);
        reloader = HotReloader(
            base_path=str(unique_dir), module_name="Button", watcher=watcher
        );
        # Initial compilation
        reloader._recompile_client_code(str(base_file));
        output_file = unique_dir / ".jac" / "client" / "compiled" / "Button.js";
        assert output_file.exists() , "Initial JS file was not created";
        content1 = output_file.read_text();
        assert "Click Me" in content1;
        # Version 2: Update impl file to change label
        impl_file.write_text(
            "cl {\n"
            "    impl ButtonProps.get_label() -> str {\n"
            '        return "Submit Now";\n'
            "    }\n"
            "}\n"
        );
        # Simulate impl file change - should trigger base file recompilation
        reloader._process_change(str(impl_file));
        # Check that JS was updated
        assert output_file.exists() , "JS file should exist after impl change";
        content2 = output_file.read_text();
        assert "Submit Now" in content2 , "JS content should reflect impl file change";
        assert "Click Me" not in content2 , "Old label should not be in updated JS";
    }
}

# --- TestHMRRecursiveDependency ---
"""When app.cl.jac imports Button.cl.jac, recompiling app should also generate Button.js."""
test "dependency compiled when imported file recompiled" {
    with TemporaryDirectory() as tmpdir {
        unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        unique_dir.mkdir(parents=True, exist_ok=True);
        # Button component in components/
        btn_file = unique_dir / "Button.cl.jac";
        btn_file.write_text(
            "cl {\n"
            "    def Button() {\n"
            "        return <button>Click</button>;\n"
            "    }\n"
            "}\n"
        );
        # App imports Button
        app_file = unique_dir / "app.cl.jac";
        app_file.write_text(
            "cl import from .Button { Button }\n"
            "cl {\n"
            "    def App() {\n"
            "        return <div><Button /></div>;\n"
            "    }\n"
            "}\n"
        );
        watcher = JacFileWatcher(watch_paths=[str(unique_dir)], _debounce_ms=50);
        reloader = HotReloader(
            base_path=str(unique_dir), module_name="app", watcher=watcher
        );
        # Compile app - should recursively compile Button as a dependency
        reloader._recompile_client_code(str(app_file));
        compiled_dir = unique_dir / ".jac" / "client" / "compiled" / "Button.js";
        assert compiled_dir.exists() , "Button.js should be compiled as a dependency of app.cl.jac";
    }
}

# --- TestUnifiedClientCompilerHMR ---
# The unified path routes HMR through the boot ViteCompiler so file-based
# routing artifacts (_routes.js, router _entry.js) stay live across changes.
def _make_unified_reloader(unique_dir: Path) -> tuple {
    import from jaclang.runtimelib.client.vite_client_bundle { ViteClientBundleBuilder }
    configs_dir = unique_dir / ".jac" / "client" / "configs";
    configs_dir.mkdir(parents=True, exist_ok=True);
    package_json = configs_dir / "package.json";
    package_json.write_text("{}");
    compiled_dir = unique_dir / ".jac" / "client" / "compiled";
    compiled_dir.mkdir(parents=True, exist_ok=True);
    builder = ViteClientBundleBuilder(vite_package_json=package_json);
    compiler = builder._get_compiler();
    # Pin outputs to this temp project regardless of any ambient jac.toml
    compiler.compiled_dir = compiled_dir;
    compiler.jac_client_compiler.compiled_dir = compiled_dir;
    watcher = JacFileWatcher(watch_paths=[str(unique_dir)], _debounce_ms=50);
    reloader = HotReloader(
        base_path=str(unique_dir),
        module_name="main",
        watcher=watcher,
        client_compiler=compiler
    );
    return (reloader, compiler, compiled_dir);
}

test "routing activates when pages are created after startup" {
    with TemporaryDirectory() as tmpdir {
        unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        unique_dir.mkdir(parents=True, exist_ok=True);
        (reloader, compiler, compiled_dir) = _make_unified_reloader(unique_dir);
        main_file = unique_dir / "main.jac";
        main_file.write_text(
            "cl {\n    def app() {\n        return <div>App</div>;\n    }\n}\n"
        );
        # No pages/ yet: a refresh must not fabricate routing artifacts
        reloader._refresh_routing(str(main_file));
        assert not (compiled_dir / "_routes.js").exists();
        # pages/ appears while the server is "running"
        pages_dir = unique_dir / "pages";
        pages_dir.mkdir();
        index_file = pages_dir / "index.jac";
        index_file.write_text(
            "cl {\n    def View() -> JsxPage {\n        return <div>Home</div>;\n    }\n}\n"
        );
        reloader._recompile_client_code(str(index_file));
        index_js = compiled_dir / "pages" / "index.js";
        assert index_js.exists();
        # Unified recompiles keep the boot pipeline's artifacts
        assert index_js.read_text().startswith("/* Source:") , "unified HMR output should keep the /* Source */ header";
        assert (compiled_dir / "pages" / "index.js.map").exists() , "unified HMR output should write a fresh source map";
        # A second page exists but never got its own change event
        # (e.g. the directory was moved into place)
        about_file = pages_dir / "about.jac";
        about_file.write_text(
            "cl {\n    def View() -> JsxPage {\n        return <div>About</div>;\n    }\n}\n"
        );
        index_mtime = index_js.stat().st_mtime_ns;
        reloader._refresh_routing(str(index_file));
        routes = (compiled_dir / "_routes.js").read_text();
        assert "PagesIndex" in routes and "PagesAbout" in routes , "both pages should be routed after the rescan";
        assert (compiled_dir / "pages" / "about.js").exists() , "rescan should compile pages that missed their change event";
        assert index_js.stat().st_mtime_ns == index_mtime , "rescan must not recompile pages whose output already exists";
        assert compiler._has_pages;
        entry = (compiled_dir / "_entry.js").read_text();
        assert "BrowserRouter" in entry , "entry must upgrade to the router form without a restart";
    }
}

test "router entry survives an error then fix cycle" {
    with TemporaryDirectory() as tmpdir {
        unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        unique_dir.mkdir(parents=True, exist_ok=True);
        (reloader, compiler, compiled_dir) = _make_unified_reloader(unique_dir);
        (unique_dir / "main.jac").write_text(
            "cl {\n    def app() {\n        return <div>App</div>;\n    }\n}\n"
        );
        pages_dir = unique_dir / "pages";
        pages_dir.mkdir();
        index_file = pages_dir / "index.jac";
        good_source = "cl {\n    def View() -> JsxPage {\n        return <div>Home</div>;\n    }\n}\n";
        index_file.write_text(good_source);
        reloader._recompile_client_code(str(index_file));
        reloader._refresh_routing(str(index_file));
        entry_file = compiled_dir / "_entry.js";
        error_file = compiled_dir.parent / ".jac-build-error.json";
        assert "BrowserRouter" in entry_file.read_text();
        # Break the page: the app entry is untouched; the error goes out-of-band
        entry_mtime = entry_file.stat().st_mtime_ns;
        index_file.write_text(
            "cl {\n    def View() -> JsxPage {\n        return <div UNCLOSED;\n    }\n}\n"
        );
        reloader._recompile_client_code(str(index_file));
        reloader._refresh_routing(str(index_file));
        assert entry_file.stat().st_mtime_ns == entry_mtime , "a build error must not touch _entry.js";
        assert "BrowserRouter" in entry_file.read_text() , "router entry must survive a build error";
        assert error_file.exists() , "build error must be mirrored for the Vite overlay";
        # The mirror must carry the real compiler message, not just exist
        # (the removed bespoke overlay had regressed to rendering empty)
        import json;
        error_data = json.loads(error_file.read_text());
        assert "index.jac" in str(error_data["file"]) , "mirrored error must name the failing file";
        assert "Failed to compile" in str(error_data["message"])
        and "index.jac" in str(error_data["message"]) , "mirrored error must carry the actual compiler message";
        # Fix the page: router still intact, mirrored error cleared
        index_file.write_text(good_source);
        reloader._recompile_client_code(str(index_file));
        reloader.record_ok();  # _process_change settles to ok after a clean rebuild
        assert "BrowserRouter" in entry_file.read_text();
        assert not error_file.exists() , "mirrored error must be removed on recovery";
    }
}

test "asset deletion removes the copy without touching the entry" {
    with TemporaryDirectory() as tmpdir {
        unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        unique_dir.mkdir(parents=True, exist_ok=True);
        (reloader, compiler, compiled_dir) = _make_unified_reloader(unique_dir);
        (unique_dir / "main.jac").write_text(
            "cl {\n    def app() {\n        return <div>App</div>;\n    }\n}\n"
        );
        pages_dir = unique_dir / "pages";
        pages_dir.mkdir();
        index_file = pages_dir / "index.jac";
        index_file.write_text(
            "cl {\n    def View() -> JsxPage {\n        return <div>Home</div>;\n    }\n}\n"
        );
        reloader._recompile_client_code(str(index_file));
        reloader._refresh_routing(str(index_file));
        entry_file = compiled_dir / "_entry.js";
        entry_mtime = entry_file.stat().st_mtime_ns;
        # Copy an asset in, then delete the source
        css_file = unique_dir / "theme.css";
        css_file.write_text("body {}");
        reloader._copy_frontend_files(str(css_file));
        copied = compiled_dir / "theme.css";
        assert copied.exists();
        css_file.unlink();
        reloader._copy_frontend_files(str(css_file));
        assert not copied.exists() , "deleted asset's copy must be removed";
        # Deletion is not an error and must not touch the app
        assert entry_file.stat().st_mtime_ns == entry_mtime , "asset deletion must not touch _entry.js";
        assert reloader.build_status()["status"] == "ok" , "asset deletion must not be reported as a build error";
        assert not (compiled_dir.parent / ".jac-build-error.json").exists();
    }
}

test "no-op routing refresh does not rewrite entry or routes" {
    with TemporaryDirectory() as tmpdir {
        unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        unique_dir.mkdir(parents=True, exist_ok=True);
        (reloader, compiler, compiled_dir) = _make_unified_reloader(unique_dir);
        (unique_dir / "main.jac").write_text(
            "cl {\n    def app() {\n        return <div>App</div>;\n    }\n}\n"
        );
        pages_dir = unique_dir / "pages";
        pages_dir.mkdir();
        index_file = pages_dir / "index.jac";
        index_file.write_text(
            "cl {\n    def View() -> JsxPage {\n        return <div>Home</div>;\n    }\n}\n"
        );
        reloader._recompile_client_code(str(index_file));
        reloader._refresh_routing(str(index_file));
        routes_file = compiled_dir / "_routes.js";
        entry_file = compiled_dir / "_entry.js";
        routes_mtime = routes_file.stat().st_mtime_ns;
        entry_mtime = entry_file.stat().st_mtime_ns;
        # Nothing changed: identical content must not be rewritten
        # (a rewrite would trigger a pointless Vite reload)
        reloader._refresh_routing(str(index_file));
        assert routes_file.stat().st_mtime_ns == routes_mtime , "_routes.js must not be rewritten when routes are unchanged";
        assert entry_file.stat().st_mtime_ns == entry_mtime , "_entry.js must not be rewritten when unchanged";
    }
}

test "deleted client module drops its stale compiled output" {
    with TemporaryDirectory() as tmpdir {
        unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        unique_dir.mkdir(parents=True, exist_ok=True);
        (reloader, compiler, compiled_dir) = _make_unified_reloader(unique_dir);
        components_dir = unique_dir / "components";
        components_dir.mkdir();
        footer_file = components_dir / "Footer.cl.jac";
        footer_file.write_text(
            "def:pub Footer() {\n    return <footer>hi</footer>;\n}\n"
        );
        reloader._recompile_client_code(str(footer_file));
        footer_js = compiled_dir / "components" / "Footer.js";
        assert footer_js.exists();
        # Delete the source: the compiled output must go too, so Vite's module
        # graph can report the broken import to whoever still imports it
        footer_file.unlink();
        reloader._remove_compiled_output(str(footer_file));
        assert not footer_js.exists() , "stale compiled JS must be removed when its source is deleted";
        assert not (compiled_dir / "components" / "Footer.js.map").exists() , "stale source map must be removed with it";
        # Deleting a module is not a build error on the Jac side
        assert reloader.build_status()["status"] == "ok";
    }
}

def _routed_project(tmpdir: str, extra_pages: dict[str, str] = {}) -> tuple {
    unique_dir = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
    unique_dir.mkdir(parents=True, exist_ok=True);
    (reloader, compiler, compiled_dir) = _make_unified_reloader(unique_dir);
    (unique_dir / "main.jac").write_text(
        "cl {\n    def app() {\n        return <div>App</div>;\n    }\n}\n"
    );
    pages_dir = unique_dir / "pages";
    pages_dir.mkdir();
    pages = {"index.jac": "Home"};
    pages.update(extra_pages);
    for (rel, label) in pages.items() {
        page_file = pages_dir / rel;
        page_file.parent.mkdir(parents=True, exist_ok=True);
        page_file.write_text(
            f"cl {{\n    def View() -> JsxPage {{\n        return <div>{label}</div>;\n    }}\n}}\n"
        );
        reloader._recompile_client_code(str(page_file));
    }
    reloader._refresh_routing(str(pages_dir / "index.jac"));
    return (reloader, compiled_dir, pages_dir);
}

test "directory moves drive the routing lifecycle" {
    with TemporaryDirectory() as tmpdir {
        (reloader, compiled_dir, pages_dir) = _routed_project(
            tmpdir, {"blog/post.jac": "Post"}
        );
        entry_file = compiled_dir / "_entry.js";
        routes_file = compiled_dir / "_routes.js";
        assert "PagesBlogPost" in routes_file.read_text();
        import shutil as sh;
        # 1. Only a subdirectory moves out: its routes and compiled output go,
        # everything else survives
        sh.move(str(pages_dir / "blog"), str(Path(tmpdir) / "blog-outside"));
        reloader._dispatch_change(str(pages_dir / "blog"), is_directory=True);
        routes = routes_file.read_text();
        assert "PagesBlogPost" not in routes and "PagesIndex" in routes , "only the moved-out subdirectory's routes may be dropped";
        assert not (compiled_dir / "pages" / "blog").exists() , "moved-out subdirectory's compiled output must be removed";
        assert (compiled_dir / "pages" / "index.js").exists();
        assert "BrowserRouter" in entry_file.read_text() , "router entry must survive a partial pages removal";
        # 2. The whole pages/ moves out: routing deactivates, artifacts cleaned
        outside = Path(tmpdir) / "outside-pages";
        sh.move(str(pages_dir), str(outside));
        reloader._dispatch_change(str(pages_dir), is_directory=True);
        assert "BrowserRouter" not in entry_file.read_text() , "entry must downgrade when pages/ disappears";
        assert not routes_file.exists() and not (compiled_dir / "pages").exists() , "orphaned routing artifacts must be removed";
        # 3. pages/ returns: routing reactivates with a fresh compile
        sh.move(str(outside), str(pages_dir));
        reloader._dispatch_change(str(pages_dir), is_directory=True);
        assert "BrowserRouter" in entry_file.read_text() , "entry must upgrade when pages/ returns";
        assert "PagesIndex" in routes_file.read_text();
        assert (compiled_dir / "pages" / "index.js").exists() , "returning pages must be recompiled";
    }
}

test "renaming a page moves its route" {
    with TemporaryDirectory() as tmpdir {
        (reloader, compiled_dir, pages_dir) = _routed_project(tmpdir);
        routes_file = compiled_dir / "_routes.js";
        assert "PagesIndex" in routes_file.read_text();
        # Rename: the watcher synthesizes DELETED(old) + CREATED(new); replay
        # the same sequence against the reloader's handling
        import os;
        old_page = pages_dir / "index.jac";
        new_page = pages_dir / "home.jac";
        os.rename(str(old_page), str(new_page));
        reloader._remove_compiled_output(str(old_page));
        reloader._refresh_routing(str(old_page));
        reloader._recompile_client_code(str(new_page));
        reloader._refresh_routing(str(new_page));
        routes = routes_file.read_text();
        assert "PagesHome" in routes and "PagesIndex" not in routes , "the route must move to the new name";
        assert (compiled_dir / "pages" / "home.js").exists();
        assert not (compiled_dir / "pages" / "index.js").exists() , "stale compiled JS of the old name must be gone";
    }
}

test "hyphenated page filenames sanitize to valid JS identifiers in _routes.js" {
    with TemporaryDirectory() as tmpdir {
        (reloader, compiled_dir, pages_dir) = _routed_project(
            tmpdir, extra_pages={"features/about-connections.jac": "About"}
        );
        routes = (compiled_dir / "_routes.js").read_text();
        assert "PagesFeaturesAboutConnections" in routes;
        for line in routes.splitlines() {
            if line.startswith("import ") {
                imported_name = line.split(" as ")[1].split(" ")[0];
                assert "-" not in imported_name , f"invalid JS identifier: {imported_name}";
            }
        }
    }
}
