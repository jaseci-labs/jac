"""Test file upload functionality in jac-scale serve."""

import contextlib
import gc
import glob
import io
import socket
import subprocess
import time
from pathlib import Path
from typing import Any

import requests


def get_free_port() -> int:
    """Get a free port by binding to port 0 and releasing it."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


class TestFileUpload:
    """Test file upload functionality in jac-scale."""

    fixtures_dir: Path
    test_file: Path
    port: int
    base_url: str
    server_process: subprocess.Popen[str] | None = None

    @classmethod
    def setup_class(cls) -> None:
        """Set up test class - runs once for all tests."""
        cls.fixtures_dir = Path(__file__).parent / "fixtures"
        cls.test_file = cls.fixtures_dir / "test_api.jac"

        if not cls.test_file.exists():
            raise FileNotFoundError(f"Test fixture not found: {cls.test_file}")

        cls.port = get_free_port()
        cls.base_url = f"http://localhost:{cls.port}"

        cls._cleanup_db_files()
        cls.server_process = None
        cls._start_server()

    @classmethod
    def teardown_class(cls) -> None:
        """Tear down test class - runs once after all tests."""
        if cls.server_process:
            cls.server_process.terminate()
            try:
                cls.server_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                cls.server_process.kill()
                cls.server_process.wait()

        time.sleep(0.5)
        gc.collect()
        cls._cleanup_db_files()

    @classmethod
    def _start_server(cls) -> None:
        """Start the jac-scale server in a subprocess."""
        import sys

        jac_executable = Path(sys.executable).parent / "jac"

        # Build the command to start the server
        # Use just the filename and set cwd to fixtures directory
        # This is required for proper bytecode caching and module resolution
        cmd = [
            str(jac_executable),
            "start",
            cls.test_file.name,
            "--port",
            str(cls.port),
        ]

        # Start the server process with cwd set to fixtures directory
        cls.server_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(cls.fixtures_dir),
        )

        max_attempts = 50
        server_ready = False

        for _ in range(max_attempts):
            if cls.server_process.poll() is not None:
                stdout, stderr = cls.server_process.communicate()
                raise RuntimeError(
                    f"Server process terminated unexpectedly.\n"
                    f"STDOUT: {stdout}\nSTDERR: {stderr}"
                )

            try:
                response = requests.get(f"{cls.base_url}/docs", timeout=2)
                if response.status_code in (200, 404):
                    print(f"Server started successfully on port {cls.port}")
                    server_ready = True
                    break
            except (requests.ConnectionError, requests.Timeout):
                time.sleep(2)

        if not server_ready:
            cls.server_process.terminate()
            try:
                stdout, stderr = cls.server_process.communicate(timeout=2)
            except subprocess.TimeoutExpired:
                cls.server_process.kill()
                stdout, stderr = cls.server_process.communicate()

            raise RuntimeError(
                f"Server failed to start after {max_attempts} attempts.\n"
                f"STDOUT: {stdout}\nSTDERR: {stderr}"
            )

    @classmethod
    def _cleanup_db_files(cls) -> None:
        """Delete SQLite database files and legacy shelf files."""
        import shutil

        for pattern in [
            "*.db",
            "*.db-wal",
            "*.db-shm",
            "anchor_store.db.dat",
            "anchor_store.db.bak",
            "anchor_store.db.dir",
        ]:
            for db_file in glob.glob(pattern):
                with contextlib.suppress(Exception):
                    Path(db_file).unlink()

        for pattern in ["*.db", "*.db-wal", "*.db-shm"]:
            for db_file in glob.glob(str(cls.fixtures_dir / pattern)):
                with contextlib.suppress(Exception):
                    Path(db_file).unlink()

        client_build_dir = cls.fixtures_dir / ".jac"
        if client_build_dir.exists():
            with contextlib.suppress(Exception):
                shutil.rmtree(client_build_dir)

    @staticmethod
    def _extract_transport_response_data(
        json_response: dict[str, Any] | list[Any],
    ) -> dict[str, Any] | list[Any]:
        """Extract data from TransportResponse envelope format."""
        if isinstance(json_response, list) and len(json_response) == 2:
            body: dict[str, Any] = json_response[1]
            json_response = body

        if (
            isinstance(json_response, dict)
            and "ok" in json_response
            and "data" in json_response
        ):
            if json_response.get("ok") and json_response.get("data") is not None:
                return json_response["data"]
            elif not json_response.get("ok") and json_response.get("error"):
                error_info = json_response["error"]
                result: dict[str, Any] = {
                    "error": error_info.get("message", "Unknown error")
                }
                if "code" in error_info:
                    result["error_code"] = error_info["code"]
                if "details" in error_info:
                    result["error_details"] = error_info["details"]
                return result

        return json_response

    def _get_auth_token(self, username: str = "filetest_user") -> str:
        """Register a user and get auth token."""
        response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": "testpass123"},
            timeout=5,
        )
        data = self._extract_transport_response_data(response.json())
        if isinstance(data, dict) and "token" in data:
            return data["token"]

        # User might already exist, try login
        response = requests.post(
            f"{self.base_url}/user/login",
            json={"username": username, "password": "testpass123"},
            timeout=5,
        )
        data = self._extract_transport_response_data(response.json())
        assert isinstance(data, dict)
        return data["token"]

    def _create_test_file(
        self, filename: str = "test.txt", content: bytes = b"Hello, World!"
    ) -> tuple[str, io.BytesIO]:
        """Create a test file-like object for upload."""
        file_obj = io.BytesIO(content)
        return filename, file_obj

    # ========================================================================
    # Single File Upload Tests
    # ========================================================================

    def test_single_file_upload_basic(self) -> None:
        """Test basic single file upload."""
        token = self._get_auth_token("single_file_user")

        filename, file_obj = self._create_test_file("document.txt", b"Test content")

        response = requests.post(
            f"{self.base_url}/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            files={"myfile": (filename, file_obj, "text/plain")},
            data={"description": "Test document"},
            timeout=10,
        )

        assert response.status_code == 200
        result = self._extract_transport_response_data(response.json())
        assert isinstance(result, dict)

        # Check walker reports are in the result
        if "reports" in result:
            reports = result["reports"]
            assert len(reports) > 0
            file_info = reports[0]
        else:
            file_info = result

        assert file_info["filename"] == "document.txt"
        assert file_info["content_type"] == "text/plain"
        assert file_info["description"] == "Test document"

    def test_single_file_upload_pdf(self) -> None:
        """Test uploading a PDF file."""
        token = self._get_auth_token("pdf_upload_user")

        # Create a minimal PDF-like content
        pdf_content = b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF"
        filename, file_obj = self._create_test_file("report.pdf", pdf_content)

        response = requests.post(
            f"{self.base_url}/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            files={"myfile": (filename, file_obj, "application/pdf")},
            data={"description": "PDF Report"},
            timeout=10,
        )

        assert response.status_code == 200
        result = self._extract_transport_response_data(response.json())
        assert isinstance(result, dict)

        file_info = result["reports"][0] if "reports" in result else result

        assert file_info["filename"] == "report.pdf"
        assert file_info["content_type"] == "application/pdf"

    def test_single_file_upload_with_empty_description(self) -> None:
        """Test file upload with default empty description."""
        token = self._get_auth_token("empty_desc_user")

        filename, file_obj = self._create_test_file("image.png", b"\x89PNG\r\n\x1a\n")

        response = requests.post(
            f"{self.base_url}/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            files={"myfile": (filename, file_obj, "image/png")},
            timeout=10,
        )

        assert response.status_code == 200
        result = self._extract_transport_response_data(response.json())
        assert isinstance(result, dict)

        file_info = result["reports"][0] if "reports" in result else result

        assert file_info["filename"] == "image.png"
        # Default description should be empty string
        assert file_info["description"] == ""

    # ========================================================================
    # Authentication Tests
    # ========================================================================

    def test_file_upload_requires_auth(self) -> None:
        """Test that private file upload walker requires authentication."""
        filename, file_obj = self._create_test_file("secret.txt", b"Secret content")

        # Try to upload without auth token
        response = requests.post(
            f"{self.base_url}/walker/SecureFileUpload",
            files={"document": (filename, file_obj, "text/plain")},
            data={"notes": "Confidential"},
            timeout=10,
        )

        # Should fail with 401 Unauthorized
        assert response.status_code in (401, 200)  # 200 if error is in response body
        if response.status_code == 200:
            result = self._extract_transport_response_data(response.json())
            assert isinstance(result, dict)
            assert "error" in result

    def test_file_upload_with_valid_auth(self) -> None:
        """Test file upload with valid authentication."""
        token = self._get_auth_token("secure_upload_user")

        filename, file_obj = self._create_test_file("confidential.doc", b"Secret data")

        response = requests.post(
            f"{self.base_url}/walker/SecureFileUpload",
            headers={"Authorization": f"Bearer {token}"},
            files={"document": (filename, file_obj, "application/msword")},
            data={"notes": "Important document"},
            timeout=10,
        )

        assert response.status_code == 200
        result = self._extract_transport_response_data(response.json())
        assert isinstance(result, dict)

        file_info = result["reports"][0] if "reports" in result else result

        assert file_info["filename"] == "confidential.doc"
        assert file_info["notes"] == "Important document"
        assert file_info["authenticated"] is True

    def test_public_file_upload_no_auth_required(self) -> None:
        """Test that public file upload walker works without authentication."""
        filename, file_obj = self._create_test_file("public.txt", b"Public content")

        response = requests.post(
            f"{self.base_url}/walker/PublicFileUpload",
            files={"attachment": (filename, file_obj, "text/plain")},
            timeout=10,
        )

        assert response.status_code == 200
        result = self._extract_transport_response_data(response.json())
        assert isinstance(result, dict)

        file_info = result["reports"][0] if "reports" in result else result

        assert file_info["filename"] == "public.txt"
        assert file_info["content_type"] == "text/plain"

    # ========================================================================
    # File Type Tests
    # ========================================================================

    def test_upload_various_file_types(self) -> None:
        """Test uploading various file types."""
        token = self._get_auth_token("various_types_user")

        file_types = [
            ("document.json", b'{"key": "value"}', "application/json"),
            ("image.jpg", b"\xff\xd8\xff\xe0", "image/jpeg"),
            ("script.js", b"console.log('hello');", "application/javascript"),
            ("data.csv", b"col1,col2\nval1,val2", "text/csv"),
        ]

        for filename, content, content_type in file_types:
            file_obj = io.BytesIO(content)

            response = requests.post(
                f"{self.base_url}/walker/UploadSingleFile",
                headers={"Authorization": f"Bearer {token}"},
                files={"myfile": (filename, file_obj, content_type)},
                data={"description": f"Testing {content_type}"},
                timeout=10,
            )

            assert response.status_code == 200, f"Failed for {filename}"
            result = self._extract_transport_response_data(response.json())
            assert isinstance(result, dict)

            file_info = result["reports"][0] if "reports" in result else result

            assert file_info["filename"] == filename
            assert file_info["content_type"] == content_type

    # ========================================================================
    # Error Handling Tests
    # ========================================================================

    def test_upload_missing_required_file(self) -> None:
        """Test upload endpoint when required file is missing."""
        token = self._get_auth_token("missing_file_user")

        # Send request without the required file
        response = requests.post(
            f"{self.base_url}/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            data={"description": "No file attached"},
            timeout=10,
        )

        # Should return validation error (422) or error in response
        assert response.status_code in (422, 400, 200)
        result = response.json()

        if response.status_code == 422:
            # FastAPI validation error
            assert "detail" in result
        elif response.status_code == 200:
            # Error in response body
            extracted = self._extract_transport_response_data(result)
            assert isinstance(extracted, dict)
            assert "error" in extracted

    def test_upload_large_file(self) -> None:
        """Test uploading a larger file (1MB)."""
        token = self._get_auth_token("large_file_user")

        # Create a 1MB file
        large_content = b"X" * (1024 * 1024)  # 1MB
        filename, file_obj = self._create_test_file("large_file.bin", large_content)

        response = requests.post(
            f"{self.base_url}/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            files={"myfile": (filename, file_obj, "application/octet-stream")},
            data={"description": "Large file test"},
            timeout=30,  # Longer timeout for large file
        )

        assert response.status_code == 200
        result = self._extract_transport_response_data(response.json())
        assert isinstance(result, dict)

        file_info = result["reports"][0] if "reports" in result else result

        assert file_info["filename"] == "large_file.bin"
        assert file_info["size"] == 1024 * 1024
