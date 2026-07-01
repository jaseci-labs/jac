"""Shared test helpers for jac-scale's HTTP server tests.

Canonical, copy-paste-free versions of small utilities that several server,
quarantine, and data tests need: allocating a free TCP port for a subprocess
server, scrubbing leftover SQLite/shelf files between runs, and unwrapping the
TransportResponse envelope returned by the API.

Example:
    import from jaclang.scale.tests.server_support { get_free_port }
    port = get_free_port();
"""

import socket;
import glob;
import shutil;
import contextlib;
import from pathlib { Path }

"""Get a free port by binding to port 0 and releasing it."""
def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        port = s.getsockname()[1];
    }
    return port;
}

"""Delete SQLite database files and legacy shelf files."""
def _cleanup_db_files(fixtures_dir: Path) {
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

"""Extract data from TransportResponse envelope format."""
def _extract_transport_response_data(
    json_response: dict[str, any] | list[any]
) -> dict[str, any] | list[any] {
    if isinstance(json_response, list) and len(json_response) == 2 {
        body: dict[str, any] = json_response[1];
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
            result: dict[str, any] = {
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
