"""Test file upload functionality in jac-scale serve."""

import contextlib;
import gc;
import glob;
import io;
import socket;
import subprocess;
import time;
import shutil;
import sys;
import requests;
import from pathlib { Path }
import from typing { Any }

"""Get a free port by binding to port 0 and releasing it."""
def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        port = s.getsockname()[1];
    }
    return port;
}

"""Extract data from TransportResponse envelope format."""
def _extract_transport_response_data(
    json_response: dict[str, Any] | list[Any]
) -> dict[str, Any] | list[Any] {
    if isinstance(json_response, list) and len(json_response) == 2 {
        body: dict[str, Any] = json_response[1];
        json_response = body;
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

"""Delete SQLite database files and legacy shelf files."""
def _cleanup_db_files(fixtures_dir: Path) -> None {
    for pattern in [
        "*.db",
        "*.db-wal",
        "*.db-shm",
        "anchor_store.db.dat",
        "anchor_store.db.bak",
        "anchor_store.db.dir"
    ] {
        for db_file in glob.glob(pattern) {
            with contextlib.suppress(Exception) {
                Path(db_file).unlink();
            }
        }
    }

    for pattern in ["*.db", "*.db-wal", "*.db-shm"] {
        for db_file in glob.glob(str(fixtures_dir / pattern)) {
            with contextlib.suppress(Exception) {
                Path(db_file).unlink();
            }
        }
    }

    client_build_dir = fixtures_dir / ".jac";
    if client_build_dir.exists() {
        with contextlib.suppress(Exception) {
            shutil.rmtree(client_build_dir);
        }
    }
}

"""Start the jac-scale server in a subprocess."""
def _start_server(
    fixtures_dir: Path, test_file: Path, port: int, base_url: str
) -> subprocess.Popen {
    jac_executable = Path(sys.executable).parent / "jac";
    cmd = [str(jac_executable), "start", test_file.name, "--port", str(port)];

    server_process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(fixtures_dir)
    );

    max_attempts = 50;
    server_ready = False;

    for _ in range(max_attempts) {
        if server_process.poll() is not None {
            (stdout, stderr) = server_process.communicate();
            raise RuntimeError(
                f"Server process terminated unexpectedly.\n"
                f"STDOUT: {stdout}\nSTDERR: {stderr}"
            ) ;
        }

        try {
            response = requests.get(f"{base_url}/docs", timeout=2);
            if response.status_code in (200, 404) {
                print(f"Server started successfully on port {port}");
                server_ready = True;
                break;
            }
        } except (requests.ConnectionError, requests.Timeout) {
            time.sleep(2);
        }
    }

    if not (server_ready) {
        server_process.terminate();
        try {
            (stdout, stderr) = server_process.communicate(timeout=2);
        } except subprocess.TimeoutExpired {
            server_process.kill();
            (stdout, stderr) = server_process.communicate();
        }
        raise RuntimeError(
            f"Server failed to start after {max_attempts} attempts.\n"
            f"STDOUT: {stdout}\nSTDERR: {stderr}"
        ) ;
    }

    return server_process;
}

"""Stop server process."""
def _stop_server(server_process: subprocess.Popen | None) -> None {
    if server_process {
        server_process.terminate();
        try {
            server_process.wait(timeout=5);
        } except subprocess.TimeoutExpired {
            server_process.kill();
            server_process.wait();
        }
    }
    time.sleep(0.5);
    gc.collect();
}

"""Register a user and get auth token."""
def _get_auth_token(base_url: str, username: str = "filetest_user") -> str {
    response = requests.post(
        f"{base_url}/user/register",
        json={"username": username, "password": "testpass123"},
        timeout=5
    );
    data = _extract_transport_response_data(response.json());
    if isinstance(data, dict) and "token" in data {
        return data["token"];
    }

    # User might already exist, try login
    response = requests.post(
        f"{base_url}/user/login",
        json={"username": username, "password": "testpass123"},
        timeout=5
    );
    data = _extract_transport_response_data(response.json());
    assert isinstance(data, dict);
    return data["token"];
}

"""Create a test file-like object for upload."""
def _create_test_file(
    filename: str = "test.txt", content: bytes = b"Hello, World!"
) -> tuple[str, io.BytesIO] {
    file_obj = io.BytesIO(content);
    return (filename, file_obj);
}

# Setup shared state
glob fixtures_dir: Path = Path(__file__).parent / "fixtures",
     test_file: Path = fixtures_dir / "test_api.jac",
     fu_port: int = get_free_port(),
     fu_base_url: str = f"http://localhost:{fu_port}";

"""Setup and start the file upload server."""
def setup_file_upload_server -> subprocess.Popen {
    if not test_file.exists() {
        raise FileNotFoundError(f"Test fixture not found: {test_file}") ;
    }
    _cleanup_db_files(fixtures_dir);
    return _start_server(fixtures_dir, test_file, fu_port, fu_base_url);
}

"""Teardown the file upload server."""
def teardown_file_upload_server(sp: subprocess.Popen | None) -> None {
    _stop_server(sp);
    _cleanup_db_files(fixtures_dir);
}

# Single File Upload Tests
test "single file upload basic" {
    sp = setup_file_upload_server();
    try {
        token = _get_auth_token(fu_base_url, "single_file_user");

        (filename, file_obj) = _create_test_file("document.txt", b"Test content");

        response = requests.post(
            f"{fu_base_url}/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            files={"myfile": (filename, file_obj, "text/plain")},
            data={"description": "Test document"},
            timeout=10
        );

        assert response.status_code == 200;
        result = _extract_transport_response_data(response.json());
        assert isinstance(result, dict);

        file_info = result;
        if "reports" in result {
            reports = result["reports"];
            assert len(reports) > 0;
            file_info = reports[0];
        }

        assert file_info["filename"] == "document.txt";
        assert file_info["content_type"] == "text/plain";
        assert file_info["description"] == "Test document";
    } finally {
        teardown_file_upload_server(sp);
    }
}

test "single file upload pdf" {
    sp = setup_file_upload_server();
    try {
        token = _get_auth_token(fu_base_url, "pdf_upload_user");

        pdf_content = b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF";
        (filename, file_obj) = _create_test_file("report.pdf", pdf_content);

        response = requests.post(
            f"{fu_base_url}/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            files={"myfile": (filename, file_obj, "application/pdf")},
            data={"description": "PDF Report"},
            timeout=10
        );

        assert response.status_code == 200;
        result = _extract_transport_response_data(response.json());
        assert isinstance(result, dict);

        file_info = result;
        if "reports" in result {
            file_info = result["reports"][0];
        }

        assert file_info["filename"] == "report.pdf";
        assert file_info["content_type"] == "application/pdf";
    } finally {
        teardown_file_upload_server(sp);
    }
}

test "single file upload with empty description" {
    sp = setup_file_upload_server();
    try {
        token = _get_auth_token(fu_base_url, "empty_desc_user");

        (filename, file_obj) = _create_test_file("image.png", b"\x89PNG\r\n\x1a\n");

        response = requests.post(
            f"{fu_base_url}/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            files={"myfile": (filename, file_obj, "image/png")},
            timeout=10
        );

        assert response.status_code == 200;
        result = _extract_transport_response_data(response.json());
        assert isinstance(result, dict);

        file_info = result;
        if "reports" in result {
            file_info = result["reports"][0];
        }

        assert file_info["filename"] == "image.png";
        assert file_info["description"] == "";
    } finally {
        teardown_file_upload_server(sp);
    }
}

# Authentication Tests
test "file upload requires auth" {
    sp = setup_file_upload_server();
    try {
        (filename, file_obj) = _create_test_file("secret.txt", b"Secret content");

        response = requests.post(
            f"{fu_base_url}/walker/SecureFileUpload",
            files={"document": (filename, file_obj, "text/plain")},
            data={"notes": "Confidential"},
            timeout=10
        );

        assert response.status_code in (401, 200);
        if response.status_code == 200 {
            result = _extract_transport_response_data(response.json());
            assert isinstance(result, dict);
            assert "error" in result;
        }
    } finally {
        teardown_file_upload_server(sp);
    }
}

test "file upload with valid auth" {
    sp = setup_file_upload_server();
    try {
        token = _get_auth_token(fu_base_url, "secure_upload_user");

        (filename, file_obj) = _create_test_file("confidential.doc", b"Secret data");

        response = requests.post(
            f"{fu_base_url}/walker/SecureFileUpload",
            headers={"Authorization": f"Bearer {token}"},
            files={"document": (filename, file_obj, "application/msword")},
            data={"notes": "Important document"},
            timeout=10
        );

        assert response.status_code == 200;
        result = _extract_transport_response_data(response.json());
        assert isinstance(result, dict);

        file_info = result;
        if "reports" in result {
            file_info = result["reports"][0];
        }

        assert file_info["filename"] == "confidential.doc";
        assert file_info["notes"] == "Important document";
        assert file_info["authenticated"] is True;
    } finally {
        teardown_file_upload_server(sp);
    }
}

test "public file upload no auth required" {
    sp = setup_file_upload_server();
    try {
        (filename, file_obj) = _create_test_file("public.txt", b"Public content");

        response = requests.post(
            f"{fu_base_url}/walker/PublicFileUpload",
            files={"attachment": (filename, file_obj, "text/plain")},
            timeout=10
        );

        assert response.status_code == 200;
        result = _extract_transport_response_data(response.json());
        assert isinstance(result, dict);

        file_info = result;
        if "reports" in result {
            file_info = result["reports"][0];
        }

        assert file_info["filename"] == "public.txt";
        assert file_info["content_type"] == "text/plain";
    } finally {
        teardown_file_upload_server(sp);
    }
}

# File Type Tests
test "upload various file types" {
    sp = setup_file_upload_server();
    try {
        token = _get_auth_token(fu_base_url, "various_types_user");

        file_types = [
            ("document.json", b'{"key": "value"}', "application/json"),
            ("image.jpg", b"\xff\xd8\xff\xe0", "image/jpeg"),
            ("script.js", b"console.log('hello');", "application/javascript"),
            ("data.csv", b"col1,col2\nval1,val2", "text/csv")
        ];

        for (filename, content, content_type) in file_types {
            file_obj = io.BytesIO(content);

            response = requests.post(
                f"{fu_base_url}/walker/UploadSingleFile",
                headers={"Authorization": f"Bearer {token}"},
                files={"myfile": (filename, file_obj, content_type)},
                data={"description": f"Testing {content_type}"},
                timeout=10
            );

            assert response.status_code == 200 , f"Failed for {filename}";
            result = _extract_transport_response_data(response.json());
            assert isinstance(result, dict);

            file_info = result;
            if "reports" in result {
                file_info = result["reports"][0];
            }

            assert file_info["filename"] == filename;
            assert file_info["content_type"] == content_type;
        }
    } finally {
        teardown_file_upload_server(sp);
    }
}

# Error Handling Tests
test "upload missing required file" {
    sp = setup_file_upload_server();
    try {
        token = _get_auth_token(fu_base_url, "missing_file_user");

        response = requests.post(
            f"{fu_base_url}/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            data={"description": "No file attached"},
            timeout=10
        );

        assert response.status_code in (422, 400, 200);
        result = response.json();

        if response.status_code == 422 {
            assert "detail" in result;
        } elif response.status_code == 200 {
            extracted = _extract_transport_response_data(result);
            assert isinstance(extracted, dict);
            assert "error" in extracted;
        }
    } finally {
        teardown_file_upload_server(sp);
    }
}

test "upload large file" {
    sp = setup_file_upload_server();
    try {
        token = _get_auth_token(fu_base_url, "large_file_user");

        large_content = b"X" * (1024 * 1024);  # 1MB
        (filename, file_obj) = _create_test_file("large_file.bin", large_content);

        response = requests.post(
            f"{fu_base_url}/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            files={"myfile": (filename, file_obj, "application/octet-stream")},
            data={"description": "Large file test"},
            timeout=30
        );

        assert response.status_code == 200;
        result = _extract_transport_response_data(response.json());
        assert isinstance(result, dict);

        file_info = result;
        if "reports" in result {
            file_info = result["reports"][0];
        }

        assert file_info["filename"] == "large_file.bin";
        assert file_info["size"] == 1024 * 1024;
    } finally {
        teardown_file_upload_server(sp);
    }
}
