import io;
import os;
import time;
import boto3;
import unittest;

import from unittest.mock { patch, MagicMock }
import from jaclang.runtimelib.storage { Storage }
import from jaclang.runtimelib.storage.local_storage { LocalStorage }
import from jaclang.scale.storage.s3_storage { S3Storage }
import from jaclang.project.config { JacConfig }


glob _LOCALSTACK: dict = {};


def _require_localstack -> str {
    if "endpoint" in _LOCALSTACK {
        return _LOCALSTACK["endpoint"];
    }
    # Dummy creds so boto3 can sign real requests against localstack.
    os.environ.setdefault("AWS_ACCESS_KEY_ID", "test");
    os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "test");
    os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1");
    try {
        import from testcontainers.core.container { DockerContainer }
    } except ImportError as e {
        raise unittest.SkipTest(f"testcontainers not available: {e}");
    }
    try {
        container = DockerContainer("localstack/localstack:3").with_env(
            "SERVICES", "s3"
        ).with_exposed_ports(
            4566
        );
        container.start();
    } except Exception as e {
        raise unittest.SkipTest(
            f"Could not start localstack (Docker unavailable?): {e}"
        );
    }

    import atexit;
    atexit.register(container.stop);

    host = container.get_container_host_ip();
    port = container.get_exposed_port(4566);
    endpoint = f"http://{host}:{port}";
    _LOCALSTACK["container"] = container;
    _LOCALSTACK["endpoint"] = endpoint;
    return endpoint;
}


def _admin_client(endpoint: str) -> any {
    # Provisions buckets independently of the S3Storage under test.
    return boto3.client(
        "s3",
        endpoint_url=endpoint,
        region_name="us-east-1",
        aws_access_key_id="test",
        aws_secret_access_key="test"
    );
}


def _ensure_bucket(bucket: str) -> any {
    # Retry so the first call doubles as a readiness wait for the fresh container.
    endpoint = _require_localstack();
    admin = _admin_client(endpoint);
    last = None;
    ready = False;
    for _ in range(30) {
        try {
            admin.create_bucket(Bucket=bucket);
            ready = True;
            break;
        } except Exception as e {
            msg = str(e);
            if "BucketAlreadyOwnedByYou" in msg
                or "BucketAlreadyExists" in msg
                or "409" in msg {
                ready = True;
                break;
            }
            last = e;
            time.sleep(1);
        }
    }
    if not ready {
        raise unittest.SkipTest(f"localstack never became ready: {last}");
    }
    resp = admin.list_objects_v2(Bucket=bucket);
    for obj in resp.get("Contents", []) {
        admin.delete_object(Bucket=bucket, Key=obj["Key"]);
    }
    return admin;
}


def get_mock_s3_storage(
    bucket: str = "test-bucket", public: bool = False
) -> S3Storage {
    endpoint = _require_localstack();
    storage = S3Storage(
        bucket=bucket, region="us-east-1", endpoint_url=endpoint, public_read=public
    );
    return storage;
}


test "s3 upload and exists" {
    _ensure_bucket("test-bucket");
    storage = get_mock_s3_storage();
    content = b"S3 Test Content";
    storage.upload(io.BytesIO(content), "test.txt");
    assert storage.exists("test.txt");
    assert storage.download("test.txt") == content;
}

test "s3 download to file" {
    _ensure_bucket("test-bucket");
    storage = get_mock_s3_storage();
    storage.upload(io.BytesIO(b"file data"), "file.txt");
    temp_file = "temp_s3_test.txt";
    try {
        storage.download("file.txt", temp_file);
        with open(temp_file, "rb") as f {
            assert f.read() == b"file data";
        }
    } finally {
        if os.path.exists(temp_file) {
            os.remove(temp_file);
        }
    }
}

test "s3 delete" {
    _ensure_bucket("test-bucket");
    storage = get_mock_s3_storage();
    storage.upload(io.BytesIO(b"data"), "delete_me.txt");
    assert storage.exists("delete_me.txt");
    storage.delete("delete_me.txt");
    assert not storage.exists("delete_me.txt");
}

test "s3 list files" {
    _ensure_bucket("test-bucket");
    storage = get_mock_s3_storage(bucket="test-bucket");
    storage.upload(io.BytesIO(b"1"), "dir/a.txt");
    storage.upload(io.BytesIO(b"2"), "dir/b.txt");
    storage.upload(io.BytesIO(b"3"), "other.txt");
    files = list(storage.list_files("dir"));
    assert len(files) == 2;
    assert "dir/a.txt" in files;
    assert "dir/b.txt" in files;
}

test "s3 get_url pre-signed" {
    _ensure_bucket("test-bucket");
    storage = get_mock_s3_storage(public=False);
    url = storage.get_url("secret.txt", expires_in=60);
    assert "test-bucket" in url;
    assert "secret.txt" in url;
    assert "X-Amz-Signature" in url;
    assert "X-Amz-Expires=60" in url;
}

test "s3 get_url public" {
    _ensure_bucket("public-bucket");
    storage = get_mock_s3_storage(bucket="public-bucket", public=True);
    url = storage.get_url("photo.jpg");
    assert "public-bucket" in url;
    assert "photo.jpg" in url;
}

test "s3 copy and move" {
    _ensure_bucket("test-bucket");
    storage = get_mock_s3_storage();
    storage.upload(io.BytesIO(b"original"), "orig.txt");
    storage.copy("orig.txt", "copy.txt");
    assert storage.exists("orig.txt");
    assert storage.exists("copy.txt");
    storage.move("orig.txt", "moved.txt");
    assert not storage.exists("orig.txt");
    assert storage.exists("moved.txt");
}

test "s3 prefix handling" {
    admin = _ensure_bucket("prefix-bucket");
    endpoint = _require_localstack();
    storage = S3Storage(
        bucket="prefix-bucket",
        prefix="my/app/",
        region="us-east-1",
        endpoint_url=endpoint
    );
    storage.upload(io.BytesIO(b"data"), "file.txt");
    response = admin.list_objects_v2(Bucket="prefix-bucket");
    assert response["Contents"][0]["Key"] == "my/app/file.txt";
    assert storage.exists("file.txt");
    assert "file.txt" in list(storage.list_files(""));
}

test "s3 get_metadata" {
    _ensure_bucket("test-bucket");
    storage = get_mock_s3_storage();
    storage.upload(io.BytesIO(b"some data"), "meta.txt");
    metadata = storage.get_metadata("meta.txt");
    assert metadata["name"] == "meta.txt";
    assert metadata["size"] == 9;
    assert "modified" in metadata;
    assert metadata["is_dir"] is False;
}

test "s3 get_url with custom endpoint" {
    # Pure URL generation with no network call, so this needs no localstack bucket.
    storage = S3Storage(
        bucket="minio-bucket",
        endpoint_url="https://minio.example.com",
        public_read=True
    );
    url = storage.get_url("image.png");
    assert url == "https://minio.example.com/minio-bucket/image.png";
}

test "s3 download nonexistent raises" {
    _ensure_bucket("test-bucket");
    storage = get_mock_s3_storage();
    try {
        storage.download("ghost.txt");
        assert False , "Should have raised an error";
    } except Exception as e {
        assert "404" in str(e);
    }
}

test "store builtin defaults to local storage" {
    cfg_patcher = patch("jaclang.scale.storage.factory.get_config");
    env_patcher = patch.dict("os.environ", {}, clear=True);

    mock_cfg = cfg_patcher.start();
    env_patcher.start();

    try {
        mock_cfg.return_value = MagicMock(storage=None);

        s = store();
        assert isinstance(s, LocalStorage);
        assert s.base_path == "./storage";
    } finally {
        env_patcher.stop();
        cfg_patcher.stop();
    }
}

test "store builtin resolves to s3 storage when configured" {
    env = {"JAC_STORAGE_TYPE": "s3", "JAC_STORAGE_S3_BUCKET": "builtin-test-bucket"};
    cfg_patcher = patch("jaclang.scale.storage.factory.get_config");
    env_patcher = patch.dict("os.environ", env);
    mock_cfg = cfg_patcher.start();
    env_patcher.start();
    try {
        mock_cfg.return_value = MagicMock(storage=None);

        s = store();
        assert isinstance(s, S3Storage);
        assert s.bucket == "builtin-test-bucket";
    } finally {
        env_patcher.stop();
        cfg_patcher.stop();
    }
}

test "jac.toml parses all s3 storage fields" {
    toml_content = """
[storage]
type = "s3"
bucket = "test-bucket"
region = "us-west-2"
prefix = "my-app/"
endpoint_url = "https://custom-s3.com"
public_read = true
""";

    config = JacConfig.from_toml_str(toml_content);

    assert config.storage.storage_type == "s3";
    assert config.storage.bucket == "test-bucket";
    assert config.storage.region == "us-west-2";
    assert config.storage.prefix == "my-app/";
    assert config.storage.endpoint_url == "https://custom-s3.com";
    assert config.storage.public_read == True;
}

test "store builtin uses values from jac.toml" {
    toml_content = """
[storage]
type = "s3"
bucket = "toml-bucket"
region = "eu-central-1"
""";

    config = JacConfig.from_toml_str(toml_content);

    cfg_patcher = patch("jaclang.scale.storage.factory.get_config");
    env_patcher = patch.dict("os.environ", {}, clear=True);
    mock_get_cfg = cfg_patcher.start();
    env_patcher.start();

    try {
        mock_get_cfg.return_value = config;

        s = store();
        assert isinstance(s, S3Storage);
        assert s.bucket == "toml-bucket";
        assert s.region == "eu-central-1";
    } finally {
        env_patcher.stop();
        cfg_patcher.stop();
    }
}

test "s3 get_url handles special characters and encoding" {
    _ensure_bucket("test-bucket");
    storage = get_mock_s3_storage(public=True);
    path = "uploads/my summer #photo.jpg";
    url = storage.get_url(path);
    assert "my%20summer%20%23photo.jpg" in url;
    assert "X-Amz-Signature" not in url;
    assert "X-Amz-Algorithm" not in url;
}

test "jac.toml parses local storage fields" {
    toml_content = """
[storage]
type = "local"
base_path = "/tmp/my-storage"
create_dirs = false
""";

    config = JacConfig.from_toml_str(toml_content);

    assert config.storage.storage_type == "local";
    assert config.storage.base_path == "/tmp/my-storage";
    assert config.storage.create_dirs == False;
}

test "store builtin uses values from jac.toml for local storage" {
    toml_content = """
[storage]
type = "local"
base_path = "/tmp/custom-local"
""";

    config = JacConfig.from_toml_str(toml_content);

    cfg_patcher = patch("jaclang.scale.storage.factory.get_config");
    env_patcher = patch.dict("os.environ", {}, clear=True);
    mock_get_cfg = cfg_patcher.start();
    env_patcher.start();

    try {
        mock_get_cfg.return_value = config;

        s = store();
        assert isinstance(s, LocalStorage);
        assert s.base_path == "/tmp/custom-local";
    } finally {
        env_patcher.stop();
        cfg_patcher.stop();
    }
}
