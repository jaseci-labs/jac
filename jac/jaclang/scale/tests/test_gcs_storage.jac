import io;
import os;
import time;
import uuid;
import tempfile;
import unittest;

import from unittest.mock { patch, MagicMock }
import from jaclang.project.config { JacConfig }
import from jaclang.scale.storage.gcs_storage { GcsStorage }


glob _EMULATOR: dict = {};


def _require_emulator -> str {
    # Start a real fake-gcs-server container once for the whole module and
    # return its http endpoint. Skips loudly if Docker / the emulator cannot run.
    if "endpoint" in _EMULATOR {
        return _EMULATOR["endpoint"];
    }
    try {
        import from testcontainers.core.container { DockerContainer }
    } except ImportError as e {
        raise unittest.SkipTest(f"testcontainers not available: {e}");
    }
    try {
        container = DockerContainer("fsouza/fake-gcs-server").with_command(
            "-scheme http -public-host storage.googleapis.com"
        ).with_exposed_ports(
            4443
        );
        container.start();
    } except Exception as e {
        raise unittest.SkipTest(
            f"Could not start fake-gcs-server (Docker unavailable?): {e}"
        );
    }

    import atexit;
    atexit.register(container.stop);

    host = container.get_container_host_ip();
    port = container.get_exposed_port(4443);
    endpoint = f"http://{host}:{port}";
    _EMULATOR["container"] = container;
    _EMULATOR["endpoint"] = endpoint;
    return endpoint;
}


def _client_factory(endpoint: str, project_id: (str | None)) -> any {
    # Build a REAL google.cloud.storage client pointed at the emulator.
    import from google.auth.credentials { AnonymousCredentials }
    import from google.cloud { storage }

    def _make(**kwargs: any) -> any {
        if project_id {
            kwargs.setdefault("project", project_id);
        } else {
            kwargs.setdefault("project", "test-project");
        }
        kwargs["credentials"] = AnonymousCredentials();
        kwargs["client_options"] = {"api_endpoint": endpoint};
        return storage.Client(**kwargs);
    }
    return _make;
}


def _ensure_bucket(client: any, bucket: str) -> None {
    # Create the bucket in the emulator, retrying so the first call also acts
    # as a readiness wait for the freshly started server.
    last = None;
    for _ in range(30) {
        try {
            client.create_bucket(bucket);
            return;
        } except Exception as e {
            name = type(e).__name__;
            if name == "Conflict" or "409" in str(e) {
                return;
            }
            last = e;
            time.sleep(1);
        }
    }
    raise unittest.SkipTest(f"fake-gcs-server never became ready: {last}");
}


def make_gcs_storage(
    bucket: (str | None) = None,
    prefix: str = "",
    public: bool = False,
    project_id: str = "test-project"
) -> GcsStorage {
    # Construct the REAL GcsStorage backed by a REAL google client that talks
    # to the fake-gcs-server emulator, with an existing bucket created for it.
    endpoint = _require_emulator();
    os.environ["STORAGE_EMULATOR_HOST"] = endpoint;
    if bucket is None {
        bucket = f"jac-test-{uuid.uuid4().hex[:12]}";
    }

    factory = _client_factory(endpoint, project_id);
    _ensure_bucket(factory(), bucket);

    with patch(
        "jaclang.scale.storage.gcs_storage.StorageClient", side_effect=factory
    ) {
        storage = GcsStorage(
            bucket=bucket, prefix=prefix, public_read=public, project_id=project_id
        );
    }
    return storage;
}


def _write_temp(data: bytes, suffix: str = ".txt") -> str {
    (fd, path) = tempfile.mkstemp(suffix=suffix);
    with os.fdopen(fd, "wb") as f {
        f.write(data);
    }
    return path;
}


test "gcs storage init wires client and bucket" {
    import from google.cloud.storage { Client as RealClient }

    storage = make_gcs_storage(
        bucket="firebase-bucket", prefix="uploads/", public=True, project_id="proj-1"
    );

    assert storage.bucket == "firebase-bucket";
    assert storage.prefix == "uploads";
    assert storage.public_read == True;
    assert storage.project_id == "proj-1";
    # The real google client and its real bucket handle are wired through.
    assert isinstance(storage._client, RealClient);
    assert storage._bucket is not None;
    assert storage._bucket.name == "firebase-bucket";
}


test "gcs upload download and exists" {
    storage = make_gcs_storage();

    key = storage.upload(io.BytesIO(b"hello"), "dir/file.txt", {"kind": "demo"});
    assert key == "dir/file.txt";

    # Round-trip through the real emulator store.
    assert storage.download("dir/file.txt") == b"hello";
    assert storage.exists("dir/file.txt") == True;
    assert storage.exists("dir/missing.txt") == False;

    # Custom metadata survives the real upload/reload round-trip.
    metadata = storage.get_metadata("dir/file.txt");
    assert metadata["metadata"] == {"kind": "demo"};
    assert metadata["size"] == 5;
}


test "gcs delete returns false for missing blob" {
    storage = make_gcs_storage();

    # Real emulator returns 404 -> NotFound -> False.
    assert storage.delete("missing/file.txt") == False;

    # And returns True once the object really exists then is deleted.
    storage.upload(io.BytesIO(b"bye"), "gone/file.txt");
    assert storage.delete("gone/file.txt") == True;
    assert storage.exists("gone/file.txt") == False;
}


test "gcs download raises FileNotFoundError for missing blob" {
    storage = make_gcs_storage();

    raised = False;
    try {
        storage.download("missing/file.txt");
    } except FileNotFoundError {
        raised = True;
    }
    assert raised;
}


test "gcs get_metadata raises FileNotFoundError for missing blob" {
    storage = make_gcs_storage();

    raised = False;
    try {
        storage.get_metadata("missing/file.txt");
    } except FileNotFoundError {
        raised = True;
    }
    assert raised;
}


test "gcs copy returns false when source vanishes after exists check" {
    storage = make_gcs_storage();

    # Source never existed in the real store, so the exists() guard returns False.
    assert storage.copy("dir/a.txt", "dir/c.txt") == False;
}


test "gcs list metadata copy move and url" {
    storage = make_gcs_storage(prefix="app/", public=False);

    a_path = _write_temp(b"1234567");
    b_path = _write_temp(b"ab");
    storage.upload(a_path, "dir/a.txt", {"foo": "bar"});
    storage.upload(b_path, "dir/b.txt");

    files = sorted(list(storage.list_files("dir")));
    assert files == ["dir/a.txt", "dir/b.txt"];

    metadata = storage.get_metadata("dir/a.txt");
    assert metadata["size"] == 7;
    assert metadata["content_type"] == "text/plain";
    assert metadata["metadata"] == {"foo": "bar"};
    assert metadata["name"] == "a.txt";

    # Real server-side copy then move against the emulator.
    assert storage.copy("dir/a.txt", "dir/c.txt") == True;
    assert storage.exists("dir/c.txt") == True;

    assert storage.move("dir/a.txt", "dir/d.txt") == True;
    assert storage.exists("dir/d.txt") == True;
    assert storage.exists("dir/a.txt") == False;

    # Public read: get_url returns the object's real public URL.
    public_storage = make_gcs_storage(prefix="app/", public=True);
    url = public_storage.get_url("dir/c.txt", 60);
    assert "dir/c.txt" in url;
}


test "store builtin resolves firebase storage when configured" {
    cfg_patcher = patch("jaclang.scale.storage.factory.get_config");
    env_patcher = patch.dict(
        "os.environ",
        {
            "JAC_STORAGE_TYPE": "firebase",
            "JAC_STORAGE_FIREBASE_BUCKET": "my-firebase-bucket",
            "JAC_STORAGE_FIREBASE_PROJECT_ID": "my-project"
        },
        clear=True
    );
    gcs_req_patcher = patch(
        "jaclang.scale.storage.gcs_storage.require_google_cloud_storage"
    );
    gcs_client_patcher = patch(
        "jaclang.scale.storage.gcs_storage.StorageClient",
        return_value=MagicMock(bucket=MagicMock(return_value=MagicMock()))
    );

    mock_cfg = cfg_patcher.start();
    env_patcher.start();
    gcs_req_patcher.start();
    gcs_client_patcher.start();
    try {
        mock_cfg.return_value = MagicMock(storage=None);

        s = store();
        assert isinstance(s, GcsStorage);
        assert s.bucket == "my-firebase-bucket";
        assert s.project_id == "my-project";
    } finally {
        gcs_client_patcher.stop();
        gcs_req_patcher.stop();
        env_patcher.stop();
        cfg_patcher.stop();
    }
}


test "jac.toml parses firebase storage fields" {
    toml_content = """
[storage]
type = "firebase"
bucket = "my-firebase-project.appspot.com"
prefix = "uploads/"
project_id = "my-firebase-project"
public_read = true
""";

    config = JacConfig.from_toml_str(toml_content);

    assert config.storage.storage_type == "firebase";
    assert config.storage.bucket == "my-firebase-project.appspot.com";
    assert config.storage.prefix == "uploads/";
    assert config.storage.project_id == "my-firebase-project";
    assert config.storage.public_read == True;
}
