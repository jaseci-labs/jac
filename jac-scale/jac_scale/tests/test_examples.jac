"""Test for running jac-scale examples and testing their APIs."""

import contextlib;
import gc;
import io;
import socket;
import subprocess;
import sys;
import time;
import requests;
import from pathlib { Path }
import from typing { Any }

import from jaclang.project.config { find_project_root }

glob JacClientExamples: Path = (
         Path(__file__).parent.parent.parent.parent / "jac-client" / "jac_client" / "examples"
     ),
     JacScaleFixtures: Path = Path(__file__).parent / "fixtures";

"""Get a free port by binding to port 0 and releasing it."""
def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        port = s.getsockname()[1];
    }
    return port;
}

class JacScaleTestRunner {
    """Helper class to run jac-scale examples and test their APIs."""
    has example_file: Path,
        port: int = 0,
        base_url: str = "",
        session_file: Path = Path("."),
        server_process: subprocess.Popen | None = None,
        token: str | None = None,
        root_id: str | None = None,
        setup_npm: bool = True,
        session_name: str = "test";

    def init(
        self, example_file: Path, session_name: str = "test", setup_npm: bool = True
    ) -> None {
        self.example_file = example_file;
        self.session_name = session_name;
        self.setup_npm = setup_npm;
        self.port = get_free_port();
        self.base_url = f"http://localhost:{self.port}";
        self.session_file = example_file.parent / f"{session_name}_{self.port}.session";
        self.server_process = None;
        self.token = None;
        self.root_id = None;
    }

    """Start the jac-scale server."""
    def start_server(self, timeout: int = 30) -> None {
        project_root_result = find_project_root(self.example_file.parent);
        if project_root_result {
            (example_dir, _) = project_root_result;
        } else {
            example_dir = self.example_file.parent;
        }

        dirs_to_clean = ["build", "dist", "node_modules", ".jac"];
        for dir_name in dirs_to_clean {
            dir_path = example_dir / dir_name;
            if dir_path.exists() {
                subprocess.run(["rm", "-rf", dir_name], cwd=example_dir, check=False);
            }
        }

        if self.setup_npm {
            print(f"Setting up example directory: {example_dir}");
            npm_install = subprocess.run(
                ["jac", "add", "--npm"],
                cwd=example_dir,
                capture_output=True,
                text=True
            );
            if npm_install.returncode != 0 {
                print(f"npm install warning: {npm_install.stderr}");
            }
            print("Example directory setup complete");
        }

        jac_executable = Path(sys.executable).parent / "jac";

        cmd = [
            str(jac_executable),
            "start",
            str(self.example_file),
            "--port",
            str(self.port)
        ];

        self.server_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=example_dir
        );

        max_attempts = timeout * 5;
        server_ready = False;

        for _ in range(max_attempts) {
            if self.server_process.poll() is not None {
                (stdout, stderr) = self.server_process.communicate();
                raise RuntimeError(
                    f"Server process terminated unexpectedly.\n"
                    f"STDOUT: {stdout}\nSTDERR: {stderr}"
                ) ;
            }

            try {
                response = requests.get(f"{self.base_url}/docs", timeout=2);
                if response.status_code in (200, 404) {
                    print(f"Server started on port {self.port}");
                    server_ready = True;
                    break;
                }
            } except (requests.ConnectionError, requests.Timeout) {
                time.sleep(0.2);
            }
        }

        if not server_ready {
            (stdout, stderr) = self.server_process.communicate(timeout=5);
            raise RuntimeError(
                f"Server failed to become ready.\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"
            ) ;
        }
    }

    """Stop the jac-scale server and clean up session files."""
    def stop_server(self) -> None {
        if self.server_process {
            self.server_process.terminate();
            try {
                self.server_process.wait(timeout=5);
            } except subprocess.TimeoutExpired {
                self.server_process.kill();
                self.server_process.wait();
            }
            if self.server_process.stdout {
                self.server_process.stdout.close();
            }
            if self.server_process.stderr {
                self.server_process.stderr.close();
            }
            gc.collect();
        }

        if self.session_file.exists() {
            session_dir = self.session_file.parent;
            prefix = self.session_file.name;
            for file in session_dir.iterdir() {
                if file.name.startswith(prefix) {
                    with contextlib.suppress(Exception) {
                        file.unlink();
                    }
                }
            }
        }

        project_root_result = find_project_root(self.example_file.parent);
        if project_root_result {
            (example_dir, _) = project_root_result;
        } else {
            example_dir = self.example_file.parent;
        }
        dirs_to_clean = [
            "build",
            "dist",
            "node_modules",
            ".jac",
            "package-lock.json",
            "uploads"
        ];
        for dir_name in dirs_to_clean {
            dir_path = example_dir / dir_name;
            if dir_path.exists() {
                subprocess.run(["rm", "-rf", dir_name], cwd=example_dir, check=False);
            }
        }
    }

    """Create a new user and store the token."""
    def create_user(self, username: str, password: str) -> dict[str, Any] {
        result = self.request(
            "POST", "/user/create", data={"username": username, "password": password}
        );
        self.token = result.get("token");
        self.root_id = result.get("root_id");
        return result;
    }

    """Login as an existing user and store the token."""
    def login(self, username: str, password: str) -> dict[str, Any] {
        result = self.request(
            "POST", "/user/login", data={"username": username, "password": password}
        );
        self.token = result.get("token");
        self.root_id = result.get("root_id");
        return result;
    }

    """Make an HTTP request to the server."""
    def request(
        self,
        method: str,
        path: str,
        data: dict[str, Any] | None = None,
        use_token: bool = False,
        timeout: int = 5,
        max_retries: int = 60,
        retry_interval: float = 2.0
    ) -> Any {
        url = f"{self.base_url}{path}";
        headers = {"Content-Type": "application/json"};

        if use_token and self.token {
            headers["Authorization"] = f"Bearer {self.token}";
        }

        response = None;
        for attempt in range(max_retries) {
            response = requests.request(
                method=method, url=url, json=data, headers=headers, timeout=timeout
            );

            if response.status_code == 503 {
                print(
                    f"[DEBUG] {path} returned 503, retrying ({attempt + 1}/{max_retries})..."
                );
                time.sleep(retry_interval);
                continue;
            }

            break;
        }

        assert response is not None , "No response received";
        json_response: Any = response.json();

        if isinstance(json_response, list) and len(json_response) == 2 {
            json_response = json_response[1];
        }

        if (
            isinstance(json_response, dict)
            and "ok" in json_response
            and "data" in json_response
        ) {
            if json_response.get("ok") and json_response.get("data") is not None {
                return json_response["data"];
            } elif not json_response.get("ok") and json_response.get("error") {
                error_info = json_response["error"];
                result: dict[str, Any] = {
                    "error": error_info.get("message", "Unknown error")
                };
                if "code" in error_info {
                    result["error_code"] = error_info["code"];
                }
                if "details" in error_info {
                    result["error_details"] = error_info["details"];
                }
                return result;
            }
        }

        return json_response;
    }

    """Make a raw HTTP request to the server."""
    def request_raw(
        self,
        method: str,
        path: str,
        data: dict[str, Any] | None = None,
        use_token: bool = False,
        timeout: int = 120,
        max_retries: int = 60,
        retry_interval: float = 2.0
    ) -> str {
        url = f"{self.base_url}{path}";
        headers = {"Content-Type": "application/json"};

        if use_token and self.token {
            headers["Authorization"] = f"Bearer {self.token}";
        }

        response = None;
        for attempt in range(max_retries) {
            try {
                response = requests.request(
                    method=method, url=url, json=data, headers=headers, timeout=timeout
                );

                if response.status_code == 503 {
                    print(
                        f"[DEBUG] {path} returned 503, retrying ({attempt + 1}/{max_retries})..."
                    );
                    time.sleep(retry_interval);
                    continue;
                }

                return response.text;
            } except requests.exceptions.Timeout {
                print(
                    f"[DEBUG] {path} timed out, retrying ({attempt + 1}/{max_retries})..."
                );
                time.sleep(retry_interval);
                continue;
            }
        }

        if response is not None {
            return response.text;
        }
        return f"Request failed after {max_retries} retries (all timeouts)";
    }

    """Spawn a walker with the given parameters."""
    def spawn_walker(self, walker_name: str, **kwargs: object) -> dict[str, Any] {
        return self.request(
            "POST", f"/walker/{walker_name}", data=kwargs, use_token=True
        );
    }

    """Upload a file to a walker endpoint using multipart/form-data."""
    def upload_file(
        self,
        walker_name: str,
        file_field: str,
        filename: str,
        content: bytes,
        content_type: str = "text/plain",
        extra_data: dict[str, Any] | None = None,
        timeout: int = 10
    ) -> Any {
        url = f"{self.base_url}/walker/{walker_name}";
        headers = {};

        if self.token {
            headers["Authorization"] = f"Bearer {self.token}";
        }

        files = {file_field: (filename, io.BytesIO(content), content_type)};
        data = extra_data or {};

        response = requests.post(
            url, headers=headers, files=files, data=data, timeout=timeout
        );

        json_response: Any = response.json();

        if isinstance(json_response, list) and len(json_response) == 2 {
            json_response = json_response[1];
        }

        if (
            isinstance(json_response, dict)
            and "ok" in json_response
            and "data" in json_response
        ) {
            if json_response.get("ok") and json_response.get("data") is not None {
                return json_response["data"];
            } elif not json_response.get("ok") and json_response.get("error") {
                error_info = json_response["error"];
                result: dict[str, Any] = {
                    "error": error_info.get("message", "Unknown error")
                };
                if "code" in error_info {
                    result["error_code"] = error_info["code"];
                }
                if "details" in error_info {
                    result["error_details"] = error_info["details"];
                }
                return result;
            }
        }

        return json_response;
    }

    """Call a function with the given parameters."""
    def call_function(self, function_name: str, **kwargs: object) -> dict[str, Any] {
        query_params = "&".join(f"{k}={v}" for (k, v) in kwargs.items());
        path = f"/function/{function_name}";
        if query_params {
            path += f"?{query_params}";
        }

        return self.request("GET", path, use_token=True);
    }

    """Context manager entry."""
    def __enter__(self) -> JacScaleTestRunner {
        self.start_server();
        return self;
    }

    """Context manager exit."""
    def __exit__(
        self,
        exc_type: type | None,
        exc_val: BaseException | None,
        exc_tb: object | None
    ) -> None {
        self.stop_server();
    }
}

# TestJacClientExamples
"""Test the all-in-one example file."""
test "all in one" {
    example_file = JacClientExamples / "all-in-one" / "main.jac";
    with JacScaleTestRunner(example_file, session_name="custom_test", setup_npm=True) as runner {
        assert "background-image" in runner.request_raw("GET", "/styles/styles.css");
        assert "PNG" in runner.request_raw("GET", "/static/assets/burger.png");
        assert "/static/client.js" in runner.request_raw("GET", "/cl/app");
        assert (
            runner.request_raw("GET", "/static/client.js") != "Static file not found"
        );
        assert (
            runner.request_raw("GET", "/static/client.jss") == "Static file not found"
        );
    }
}

"""Test JS and styling example file."""
test "js styling" {
    example_file = JacClientExamples / "css-styling" / "js-styling" / "main.jac";
    with JacScaleTestRunner(
        example_file, session_name="js_styling_test", setup_npm=True
    ) as runner {
        assert "const countDisplay" in runner.request_raw("GET", "/styles.js");
        assert "/static/client.js" in runner.request_raw("GET", "/cl/app");
    }
}

"""Test Material-UI styling example."""
test "material ui" {
    example_file = JacClientExamples / "css-styling" / "material-ui" / "main.jac";
    with JacScaleTestRunner(
        example_file, session_name="material_ui_test", setup_npm=True
    ) as runner {
        assert "/static/client.js" in runner.request_raw("GET", "/cl/app");
    }
}

"""Test Pure CSS example."""
test "pure css" {
    example_file = JacClientExamples / "css-styling" / "pure-css" / "main.jac";
    with JacScaleTestRunner(example_file, session_name="pure_css_test", setup_npm=True) as runner {
        page_content = runner.request_raw("GET", "/cl/app");
        assert "/static/client.js" in page_content;
        assert ".container {" in runner.request_raw("GET", "/styles.css");
    }
}

"""Test Styled Components example."""
test "styled components" {
    example_file = (
        JacClientExamples / "css-styling" / "styled-components" / "main.jac"
    );
    with JacScaleTestRunner(
        example_file, session_name="styled_components_test", setup_npm=True
    ) as runner {
        assert "/static/client.js" in runner.request_raw("GET", "/cl/app");
        assert "import styled from" in runner.request_raw("GET", "/styled.js");
    }
}

# TestJacScaleFeatures
"""Test Storage API with file upload, list, download, copy, move, delete."""
test "storage api" {
    example_file = JacScaleFixtures / "scale-feats" / "main.jac";
    with JacScaleTestRunner(
        example_file, session_name="storage_api_test", setup_npm=False
    ) as runner {
        # Health check
        health = runner.spawn_walker("health");
        assert health.get("reports", [[]])[0].get("status") == "ok";
        # Register user for auth
        runner.create_user("storage_user", "testpass123");
        # Test file upload
        test_content = b"Test content for storage API";
        upload_result = runner.upload_file(
            walker_name="upload_file",
            file_field="file",
            filename="test_file.txt",
            content=test_content,
            content_type="text/plain",
            extra_data={"folder": "test_docs"}
        );
        reports = upload_result.get("reports", []);
        assert len(reports) > 0 , "Upload should return reports";
        file_info = reports[0];
        assert file_info["success"] is True;
        assert file_info["original_filename"] == "test_file.txt";
        assert "storage_path" in file_info;
        uploaded_path = file_info["storage_path"];
        assert uploaded_path.startswith("test_docs/");
        assert file_info["size"] == len(test_content);
        # Test file exists
        exists_result = runner.spawn_walker("file_exists", path=uploaded_path);
        reports = exists_result.get("reports", []);
        assert len(reports) > 0;
        assert reports[0]["exists"] is True;
        # Test list files
        list_result = runner.spawn_walker("list_files", folder="", recursive=True);
        reports = list_result.get("reports", []);
        assert len(reports) > 0;
        list_info = reports[0];
        assert "files" in list_info;
        assert list_info["count"] >= 1;
        file_paths = [f["path"] for f in list_info["files"]];
        assert uploaded_path in file_paths;
        # Test download file
        download_result = runner.spawn_walker("download_file", path=uploaded_path);
        reports = download_result.get("reports", []);
        assert len(reports) > 0;
        assert reports[0]["success"] is True;
        assert reports[0]["content_length"] == len(test_content);
        # Test copy file
        copy_dest = "test_docs/copied_file.txt";
        copy_result = runner.spawn_walker(
            "copy_file", source=uploaded_path, destination=copy_dest
        );
        reports = copy_result.get("reports", []);
        assert len(reports) > 0;
        assert reports[0]["success"] is True;
        # Verify copy exists
        exists_result = runner.spawn_walker("file_exists", path=copy_dest);
        assert exists_result.get("reports", [[]])[0]["exists"] is True;
        # Test move file
        move_dest = "test_docs/moved_file.txt";
        move_result = runner.spawn_walker(
            "move_file", source=copy_dest, destination=move_dest
        );
        reports = move_result.get("reports", []);
        assert len(reports) > 0;
        assert reports[0]["success"] is True;
        # Verify move: source gone, dest exists
        exists_result = runner.spawn_walker("file_exists", path=copy_dest);
        assert exists_result.get("reports", [[]])[0]["exists"] is False;
        exists_result = runner.spawn_walker("file_exists", path=move_dest);
        assert exists_result.get("reports", [[]])[0]["exists"] is True;
        # Test delete file
        delete_result = runner.spawn_walker("delete_file", path=uploaded_path);
        reports = delete_result.get("reports", []);
        assert len(reports) > 0;
        assert reports[0]["success"] is True;
        # Verify deleted
        exists_result = runner.spawn_walker("file_exists", path=uploaded_path);
        assert exists_result.get("reports", [[]])[0]["exists"] is False;
        # Test delete nonexistent file
        delete_result = runner.spawn_walker("delete_file", path="nonexistent/file.txt");
        reports = delete_result.get("reports", []);
        assert len(reports) > 0;
        assert reports[0]["success"] is False;
        assert reports[0]["error"] == "File not found";
        # Cleanup: delete moved file
        runner.spawn_walker("delete_file", path=move_dest);
    }
}
