"""Implementation of the PyPI uploader."""

import base64;
import hashlib;
import io;
import os;
import random;
import string;
import urllib.request;
import urllib.error;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.publish.metadata { normalize_package_name }

# ===============================================================================
# Internal helpers
# ===============================================================================
def _resolve_url(repository: str) -> str {
    if repository.startswith("http") {
        return repository;
    }
    url = REPOSITORY_URLS.get(repository);
    if url is None {
        raise ValueError(
            f"Unknown repository '{repository}'. "
            f"Use 'pypi', 'testpypi', or a full https:// URL."
        );
    }
    return url;
}

def _credentials_file_path -> Path {
    return Path.home() / ".jac" / "credentials.toml";
}

def _build_multipart(fields: dict, filename: str, file_data: bytes,) -> tuple {
    boundary = "".join(random.choices(string.ascii_letters + string.digits, k=32));
    buf = io.BytesIO();

    # Text fields
    for (name, value) in fields.items() {
        buf.write(f"--{boundary}\r\n".encode());
        buf.write(f'Content-Disposition: form-data; name="{name}"\r\n'.encode());
        buf.write(b"\r\n");
        buf.write(value.encode("utf-8") if isinstance(value, str) else value);
        buf.write(b"\r\n");
    }

    # File field
    buf.write(f"--{boundary}\r\n".encode());
    buf.write(
        f'Content-Disposition: form-data; name="content"; filename="{filename}"\r\n'.encode()
    );
    buf.write(b"Content-Type: application/octet-stream\r\n");
    buf.write(b"\r\n");
    buf.write(file_data);
    buf.write(b"\r\n");

    buf.write(f"--{boundary}--\r\n".encode());
    return (boundary, buf.getvalue());
}

def _make_upload_result(
    status: int, body: str, filename: str, repo_url: str
) -> UploadResult {
    success = status == 200;

    # Derive the human-readable PyPI release URL from the upload URL
    release_url = "";
    if success {
        if "pypi.org" in repo_url {
            # Strip the package name from the filename to build the URL
            pkg_ver = filename.rsplit("-", 3)[0:2];
            if len(pkg_ver) == 2 {
                release_url = f"https://pypi.org/project/{pkg_ver[0]}/{pkg_ver[1]}/";
            }
        }
    }

    # Map known status codes to readable messages
    messages: dict[int, str] = {
        200: f"Successfully uploaded {filename}",
        400: f"Bad request: {body}",
        401: "Authentication required. Check your credentials.",
        403: "Permission denied. Verify your API token has upload rights.",
        409: f"Version already exists on the repository: {filename}",
        410: "Package name is unavailable (may be taken or banned).",
        413: "Wheel file is too large for this repository.",
        500: f"Server error: {body}",

    };
    message = messages.get(status, f"HTTP {status}: {body}");

    return UploadResult(
        success=success, status_code=status, message=message, release_url=release_url,
    );
}

# ===============================================================================
# load_credentials
# ===============================================================================
impl load_credentials(repository: str = "pypi") -> PyPICredentials {
    import tomllib;
    upload_url = _resolve_url(repository);

    # 1. JAC_PYPI_TOKEN shorthand (API token only)
    token = os.environ.get("JAC_PYPI_TOKEN", "");
    if token {
        return PyPICredentials(
            username="__token__", password=token, repository_url=upload_url,
        );
    }

    # 2. JAC_PYPI_USERNAME + JAC_PYPI_PASSWORD
    username = os.environ.get("JAC_PYPI_USERNAME", "");
    password = os.environ.get("JAC_PYPI_PASSWORD", "");
    if username and password {
        return PyPICredentials(
            username=username, password=password, repository_url=upload_url,
        );
    }

    # 3. TWINE_USERNAME + TWINE_PASSWORD (compatibility)
    username = os.environ.get("TWINE_USERNAME", "");
    password = os.environ.get("TWINE_PASSWORD", "");
    if username and password {
        return PyPICredentials(
            username=username, password=password, repository_url=upload_url,
        );
    }

    # 4. ~/.jac/credentials.toml
    creds_path = _credentials_file_path();
    if creds_path.is_file() {
        with open(creds_path, "rb") as f {
            data = tomllib.load(f);
        }
        # Resolve section name: named repo → section key; URL → "custom"
        section_key = repository if not repository.startswith("http") else "custom";
        section = data.get(section_key, {});
        username = section.get("username", "");
        password = section.get("password", "");
        if username and password {
            return PyPICredentials(
                username=username, password=password, repository_url=upload_url,
            );
        }
    }

    raise ValueError(
        f"No credentials found for repository '{repository}'.\n"
        "Set JAC_PYPI_TOKEN (or JAC_PYPI_USERNAME + JAC_PYPI_PASSWORD),\n"
        f"or add a [{repository}] section to {_credentials_file_path()}."
    );
}

# ===============================================================================
# upload_wheel
# ===============================================================================
impl upload_wheel(
    wheel_path: Path, config: JacConfig, credentials: PyPICredentials | None = None,
) -> UploadResult {
    wheel_bytes = wheel_path.read_bytes();
    return upload_wheel_bytes(
        wheel_bytes=wheel_bytes,
        filename=wheel_path.name,
        config=config,
        credentials=credentials,
    );
}

# ===============================================================================
# upload_wheel_bytes
# ===============================================================================
impl upload_wheel_bytes(
    wheel_bytes: bytes,
    filename: str,
    config: JacConfig,
    credentials: PyPICredentials | None = None,
) -> UploadResult {
    if config.package is None {
        raise ValueError(
            "Cannot upload wheel: [package] section is missing in jac.toml."
        );
    }

    if credentials is None {
        credentials = load_credentials();
    }

    pkg = config.package;

    # Compute digests
    md5_hex = hashlib.md5(wheel_bytes).hexdigest();  # noqa: S324 (legacy PyPI req)
    sha2_hex = hashlib.sha256(wheel_bytes).hexdigest();

    # Build the multipart form fields required by PyPI's legacy upload API
    fields: dict = {
        ":action": "file_upload",
        "protocol_version": "1",
        "name": normalize_package_name(pkg.name),
        "version": pkg.version,
        "filetype": "bdist_wheel",
        "pyversion": "py3",
        "md5_digest": md5_hex,
        "sha2_digest": sha2_hex,

    };

    (boundary, body) = _build_multipart(fields, filename, wheel_bytes);

    # Build request
    request = urllib.request.Request(
        url=credentials.repository_url, data=body, method="POST",
    );
    request.add_header("Content-Type", f"multipart/form-data; boundary={boundary}");

    # HTTP Basic Auth
    auth_token = base64.b64encode(
        f"{credentials.username}:{credentials.password}".encode()
    ).decode();
    request.add_header("Authorization", f"Basic {auth_token}");

    # Send
    try {
        with urllib.request.urlopen(request) as resp {
            status = resp.status;
            response_body = resp.read().decode("utf-8", errors="replace");
        }
    } except urllib.error.HTTPError as e {
        status = e.code;
        try {
            response_body = e.read().decode("utf-8", errors="replace");
        } except Exception {
            response_body = str(e);
        }
    } except urllib.error.URLError as e {
        return UploadResult(
            success=False, status_code=0, message=f"Network error: {e.reason}",
        );
    }

    return _make_upload_result(
        status, response_body, filename, credentials.repository_url
    );
}
