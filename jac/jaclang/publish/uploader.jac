"""PyPI uploader for jac publish — uses the legacy upload API compatible with twine."""

import from pathlib { Path }
import from jaclang.project.config { JacConfig }

# Known repository name → upload URL mapping.
glob REPOSITORY_URLS: dict[str, str] = {
         "pypi": "https://upload.pypi.org/legacy/",
         "testpypi": "https://test.pypi.org/legacy/",

     };

"""PyPI credentials and upload endpoint."""
obj PyPICredentials {
    has username: str = "",
        password: str = "",
        repository_url: str = "https://upload.pypi.org/legacy/";
}

"""Outcome of a single upload attempt."""
obj UploadResult {
    has success: bool = False,
        status_code: int = 0,
        message: str = "",
        release_url: str = "";  # e.g. https://pypi.org/project/byllm/0.6.4/
}

"""Load PyPI credentials for the named repository; raises ValueError when none are found."""
def load_credentials(repository: str = "pypi") -> PyPICredentials;

"""Upload a wheel file from disk; credentials are loaded automatically when None."""
def upload_wheel(
    wheel_path: Path, config: JacConfig, credentials: PyPICredentials | None = None,
) -> UploadResult;

"""Upload wheel bytes from memory; filename must be the canonical .whl filename."""
def upload_wheel_bytes(
    wheel_bytes: bytes,
    filename: str,
    config: JacConfig,
    credentials: PyPICredentials | None = None,
) -> UploadResult;
