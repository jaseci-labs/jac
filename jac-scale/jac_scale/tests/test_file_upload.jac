"""Test file upload functionality in jac-scale serve."""

import io;
import from typing { Any }
import from jac_scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
}

"""Create a test file-like object for upload."""
def _create_test_file(
    filename: str = "test.txt", content: bytes = b"Hello, World!"
) -> tuple[str, io.BytesIO] {
    file_obj = io.BytesIO(content);
    return (filename, file_obj);
}

# Single File Upload Tests
test "single file upload basic" {
    client = make_client();
    try {
        (_, token) = client.register_user("single_file_user", "testpass123");

        (filename, file_obj) = _create_test_file("document.txt", b"Test content");

        response = client.post(
            "/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            files={"myfile": (filename, file_obj, "text/plain")},
            data={"description": "Test document"}
        );

        assert response.status_code == 200;
        result = extract_data(response.json());
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
        client.close();
    }
}

test "single file upload pdf" {
    client = make_client();
    try {
        (_, token) = client.register_user("pdf_upload_user", "testpass123");

        pdf_content = b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF";
        (filename, file_obj) = _create_test_file("report.pdf", pdf_content);

        response = client.post(
            "/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            files={"myfile": (filename, file_obj, "application/pdf")},
            data={"description": "PDF Report"}
        );

        assert response.status_code == 200;
        result = extract_data(response.json());
        assert isinstance(result, dict);

        file_info = result;
        if "reports" in result {
            file_info = result["reports"][0];
        }

        assert file_info["filename"] == "report.pdf";
        assert file_info["content_type"] == "application/pdf";
    } finally {
        client.close();
    }
}

test "single file upload with empty description" {
    client = make_client();
    try {
        (_, token) = client.register_user("empty_desc_user", "testpass123");

        (filename, file_obj) = _create_test_file("image.png", b"\x89PNG\r\n\x1a\n");

        response = client.post(
            "/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            files={"myfile": (filename, file_obj, "image/png")}
        );

        assert response.status_code == 200;
        result = extract_data(response.json());
        assert isinstance(result, dict);

        file_info = result;
        if "reports" in result {
            file_info = result["reports"][0];
        }

        assert file_info["filename"] == "image.png";
        assert file_info["description"] == "";
    } finally {
        client.close();
    }
}

# Authentication Tests
test "file upload requires auth" {
    client = make_client();
    try {
        (filename, file_obj) = _create_test_file("secret.txt", b"Secret content");

        response = client.post(
            "/walker/SecureFileUpload",
            files={"document": (filename, file_obj, "text/plain")},
            data={"notes": "Confidential"}
        );

        assert response.status_code in (401, 200);
        if response.status_code == 200 {
            result = extract_data(response.json());
            assert isinstance(result, dict);
            assert "error" in result;
        }
    } finally {
        client.close();
    }
}

test "file upload with valid auth" {
    client = make_client();
    try {
        (_, token) = client.register_user("secure_upload_user", "testpass123");

        (filename, file_obj) = _create_test_file("confidential.doc", b"Secret data");

        response = client.post(
            "/walker/SecureFileUpload",
            headers={"Authorization": f"Bearer {token}"},
            files={"document": (filename, file_obj, "application/msword")},
            data={"notes": "Important document"}
        );

        assert response.status_code == 200;
        result = extract_data(response.json());
        assert isinstance(result, dict);

        file_info = result;
        if "reports" in result {
            file_info = result["reports"][0];
        }

        assert file_info["filename"] == "confidential.doc";
        assert file_info["notes"] == "Important document";
        assert file_info["authenticated"] is True;
    } finally {
        client.close();
    }
}

test "public file upload no auth required" {
    client = make_client();
    try {
        (filename, file_obj) = _create_test_file("public.txt", b"Public content");

        response = client.post(
            "/walker/PublicFileUpload",
            files={"attachment": (filename, file_obj, "text/plain")}
        );

        assert response.status_code == 200;
        result = extract_data(response.json());
        assert isinstance(result, dict);

        file_info = result;
        if "reports" in result {
            file_info = result["reports"][0];
        }

        assert file_info["filename"] == "public.txt";
        assert file_info["content_type"] == "text/plain";
    } finally {
        client.close();
    }
}

# File Type Tests
test "upload various file types" {
    client = make_client();
    try {
        (_, token) = client.register_user("various_types_user", "testpass123");

        file_types = [
            ("document.json", b'{"key": "value"}', "application/json"),
            ("image.jpg", b"\xff\xd8\xff\xe0", "image/jpeg"),
            ("script.js", b"console.log('hello');", "application/javascript"),
            ("data.csv", b"col1,col2\nval1,val2", "text/csv")
        ];

        for (filename, content, content_type) in file_types {
            file_obj = io.BytesIO(content);

            response = client.post(
                "/walker/UploadSingleFile",
                headers={"Authorization": f"Bearer {token}"},
                files={"myfile": (filename, file_obj, content_type)},
                data={"description": f"Testing {content_type}"}
            );

            assert response.status_code == 200 , f"Failed for {filename}";
            result = extract_data(response.json());
            assert isinstance(result, dict);

            file_info = result;
            if "reports" in result {
                file_info = result["reports"][0];
            }

            assert file_info["filename"] == filename;
            assert file_info["content_type"] == content_type;
        }
    } finally {
        client.close();
    }
}

# Error Handling Tests
test "upload missing required file" {
    client = make_client();
    try {
        (_, token) = client.register_user("missing_file_user", "testpass123");

        response = client.post(
            "/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            data={"description": "No file attached"}
        );

        assert response.status_code in (422, 400, 200);
        result = response.json();

        if response.status_code == 422 {
            assert "detail" in result;
        } elif response.status_code == 200 {
            extracted = extract_data(result);
            assert isinstance(extracted, dict);
            assert "error" in extracted;
        }
    } finally {
        client.close();
    }
}

test "upload large file" {
    client = make_client();
    try {
        (_, token) = client.register_user("large_file_user", "testpass123");

        large_content = b"X" * (1024 * 1024);  # 1MB
        (filename, file_obj) = _create_test_file("large_file.bin", large_content);

        response = client.post(
            "/walker/UploadSingleFile",
            headers={"Authorization": f"Bearer {token}"},
            files={"myfile": (filename, file_obj, "application/octet-stream")},
            data={"description": "Large file test"}
        );

        assert response.status_code == 200;
        result = extract_data(response.json());
        assert isinstance(result, dict);

        file_info = result;
        if "reports" in result {
            file_info = result["reports"][0];
        }

        assert file_info["filename"] == "large_file.bin";
        assert file_info["size"] == 1024 * 1024;
    } finally {
        client.close();
    }
}
