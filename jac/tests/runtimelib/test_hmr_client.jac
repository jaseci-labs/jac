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
            assert resp2.data.get("result") == 15 ,  # 5 * 3
             f"Expected 15 (5*3), got {resp2.data.get('result')} - code change not applied";
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
test "server impl file reloads base jac file" {
    """Test that changing a .impl.jac file triggers reload of its base .jac file."""
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

test "client impl file reloads base cl.jac file" {
    """Test that changing a .impl.jac file triggers recompilation of its base .cl.jac file."""
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
