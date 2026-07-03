import io;
import datetime;

import from unittest.mock { patch, MagicMock }
import from jaclang.project.config { JacConfig }
import from jaclang.scale.storage.gcs_storage { GcsStorage }


def get_mock_gcs_storage(
    bucket: str = "test-bucket",
    prefix: str = "",
    public: bool = False,
    project_id: str = "test-project"
) -> tuple[GcsStorage, MagicMock, MagicMock, MagicMock] {
    client = MagicMock();
    bucket_obj = MagicMock();
    blob = MagicMock();
    client.bucket.return_value = bucket_obj;
    bucket_obj.blob.return_value = blob;

    with patch("jaclang.scale.storage.gcs_storage.require_google_cloud_storage"), patch(
        "jaclang.scale.storage.gcs_storage.StorageClient", return_value=client
    ) {
        storage = GcsStorage(
            bucket=bucket, prefix=prefix, public_read=public, project_id=project_id
        );
    }

    return (storage, client, bucket_obj, blob);
}

test "gcs storage init wires client and bucket" {
    (storage, client, bucket_obj, _) = get_mock_gcs_storage(
        bucket="firebase-bucket", prefix="uploads/", public=True, project_id="proj-1"
    );

    assert storage.bucket == "firebase-bucket";
    assert storage.prefix == "uploads";
    assert storage.public_read == True;
    assert storage.project_id == "proj-1";
    client.bucket.assert_called_once_with("firebase-bucket");
    assert storage._bucket == bucket_obj;
}

test "gcs upload download and exists" {
    (storage, _, _, blob) = get_mock_gcs_storage();
    blob.download_as_bytes.return_value = b"hello";
    blob.exists.return_value = True;

    key = storage.upload(io.BytesIO(b"hello"), "dir/file.txt", {"kind": "demo"});
    assert key == "dir/file.txt";
    assert blob.metadata == {"kind": "demo"};
    blob.upload_from_file.assert_called_once();

    assert storage.download("dir/file.txt") == b"hello";
    assert storage.exists("dir/file.txt") == True;
}

test "gcs delete returns false for missing blob" {
    import from google.cloud.exceptions { NotFound }

    (storage, _, _, blob) = get_mock_gcs_storage();
    blob.delete.side_effect = NotFound("missing");

    assert storage.delete("missing/file.txt") == False;
}

test "gcs download raises FileNotFoundError for missing blob" {
    import from google.cloud.exceptions { NotFound }

    (storage, _, _, blob) = get_mock_gcs_storage();
    blob.download_as_bytes.side_effect = NotFound("missing");

    raised = False;
    try {
        storage.download("missing/file.txt");
    } except FileNotFoundError {
        raised = True;
    }
    assert raised;
}

test "gcs get_metadata raises FileNotFoundError for missing blob" {
    import from google.cloud.exceptions { NotFound }

    (storage, _, _, blob) = get_mock_gcs_storage();
    blob.reload.side_effect = NotFound("missing");

    raised = False;
    try {
        storage.get_metadata("missing/file.txt");
    } except FileNotFoundError {
        raised = True;
    }
    assert raised;
}

test "gcs copy returns false when source vanishes after exists check" {
    import from google.cloud.exceptions { NotFound }

    (storage, _, bucket_obj, blob) = get_mock_gcs_storage();
    blob.exists.return_value = True;
    bucket_obj.copy_blob.side_effect = NotFound("vanished");

    assert storage.copy("dir/a.txt", "dir/c.txt") == False;
}

test "gcs list metadata copy move and url" {
    (storage, client, bucket_obj, blob) = get_mock_gcs_storage(
        prefix="app/", public=False
    );
    dir_blob = MagicMock();
    dir_blob.name = "app/dir/";
    file1 = MagicMock();
    file1.name = "app/dir/a.txt";
    file2 = MagicMock();
    file2.name = "app/dir/b.txt";
    bucket_obj.list_blobs.return_value = [dir_blob, file1, file2];
    blob.size = 7;
    blob.updated = datetime.datetime.now(datetime.timezone.utc);
    blob.content_type = "text/plain";
    blob.metadata = {"foo": "bar"};
    blob.exists.return_value = True;
    blob.generate_signed_url.return_value = "https://signed.example/file";
    bucket_obj.copy_blob.return_value = MagicMock();

    files = list(storage.list_files("dir"));
    assert files == ["dir/a.txt", "dir/b.txt"];

    metadata = storage.get_metadata("dir/a.txt");
    assert metadata["size"] == 7;
    assert metadata["content_type"] == "text/plain";
    assert metadata["metadata"] == {"foo": "bar"};
    assert metadata["name"] == "a.txt";

    assert storage.copy("dir/a.txt", "dir/c.txt") == True;
    assert storage.move("dir/a.txt", "dir/d.txt") == True;
    assert storage.get_url("dir/c.txt", 60) == "https://signed.example/file";
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
