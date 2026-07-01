import os;
import from unittest.mock { patch, MagicMock }
import from jaclang.scale.config.firebase_env {
    FIREBASE_AUTH_PROJECT_ID_ENV,
    FIREBASE_PROJECT_ID_ENV,
    FIRESTORE_PROJECT_ID_ENV,
    JAC_STORAGE_FIREBASE_PROJECT_ID_ENV,
    resolve_firebase_project_id
}
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
import from jaclang.scale.storage.factory { StorageFactory }


test "resolve_firebase_project_id prefers subsystem env over shared" {
    with patch.dict(
        os.environ,
        {
            FIREBASE_PROJECT_ID_ENV: "shared-project",
            FIRESTORE_PROJECT_ID_ENV: "firestore-project"
        },
        clear=True
    ) {
        assert resolve_firebase_project_id(FIRESTORE_PROJECT_ID_ENV) == "firestore-project";
    }
}


test "resolve_firebase_project_id falls back to shared env" {
    with patch.dict(
        os.environ, {FIREBASE_PROJECT_ID_ENV: "shared-project"}, clear=True
    ) {
        assert resolve_firebase_project_id(FIREBASE_AUTH_PROJECT_ID_ENV) == "shared-project";
        assert resolve_firebase_project_id(FIRESTORE_PROJECT_ID_ENV) == "shared-project";
    }
}


test "resolve_firebase_project_id falls back to config value" {
    with patch.dict(os.environ, {}, clear=True) {
        assert (
            resolve_firebase_project_id(FIRESTORE_PROJECT_ID_ENV, "toml-project") == "toml-project"
        );
    }
}


test "sso config uses FIREBASE_PROJECT_ID fallback" {
    with patch.dict(
        os.environ, {FIREBASE_PROJECT_ID_ENV: "shared-project"}, clear=True
    ) {
        reset_scale_config();
        try {
            sso_config = get_scale_config().get_sso_config();
            assert sso_config["firebase"]["project_id"] == "shared-project";
        } finally {
            reset_scale_config();
        }
    }
}


test "database config uses FIREBASE_PROJECT_ID fallback" {
    with patch.dict(
        os.environ, {FIREBASE_PROJECT_ID_ENV: "shared-project"}, clear=True
    ) {
        reset_scale_config();
        try {
            db_config = get_scale_config().get_database_config();
            assert db_config["project_id"] == "shared-project";
        } finally {
            reset_scale_config();
        }
    }
}


def _mock_storage_factory_get_default(env: dict[str, str]) -> any {
    cfg_patcher = patch("jaclang.scale.storage.factory.get_config");
    env_patcher = patch.dict("os.environ", env, clear=True);
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
        mock_cfg.return_value = None;
        return StorageFactory.get_default();
    } finally {
        gcs_client_patcher.stop();
        gcs_req_patcher.stop();
        env_patcher.stop();
        cfg_patcher.stop();
    }
}


test "storage get_default uses FIREBASE_PROJECT_ID fallback" {
    storage = _mock_storage_factory_get_default(
        {
            "JAC_STORAGE_TYPE": "firebase",
            "JAC_STORAGE_FIREBASE_BUCKET": "my-bucket",
            FIREBASE_PROJECT_ID_ENV: "shared-project"
        }
    );
    assert storage.project_id == "shared-project";
}


test "storage subsystem env overrides FIREBASE_PROJECT_ID" {
    storage = _mock_storage_factory_get_default(
        {
            "JAC_STORAGE_TYPE": "firebase",
            "JAC_STORAGE_FIREBASE_BUCKET": "my-bucket",
            FIREBASE_PROJECT_ID_ENV: "shared-project",
            JAC_STORAGE_FIREBASE_PROJECT_ID_ENV: "storage-project"
        }
    );
    assert storage.project_id == "storage-project";
}


test "GCS storage type accepts FIREBASE-aliased env vars" {
    storage = _mock_storage_factory_get_default(
        {
            "JAC_STORAGE_TYPE": "gcs",
            "JAC_STORAGE_FIREBASE_BUCKET": "aliased-bucket",
            "JAC_STORAGE_FIREBASE_PREFIX": "aliased/",
            "JAC_STORAGE_FIREBASE_PUBLIC_READ": "true"
        }
    );
    assert storage.bucket == "aliased-bucket";
    assert storage.prefix == "aliased";
    assert storage.public_read == True;
}


def _mock_storage_factory_with_toml(env: dict[str, str], toml: any) -> any {
    cfg_patcher = patch("jaclang.scale.storage.factory.get_config");
    env_patcher = patch.dict("os.environ", env, clear=True);
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
        mock_cfg.return_value = toml;
        return StorageFactory.get_default();
    } finally {
        gcs_client_patcher.stop();
        gcs_req_patcher.stop();
        env_patcher.stop();
        cfg_patcher.stop();
    }
}


test "public_read env aliases override jac.toml storage section" {
    toml = MagicMock();
    toml.storage = MagicMock(
        bucket="toml-bucket", prefix="", project_id=None, public_read=False
    );
    storage = _mock_storage_factory_with_toml(
        {"JAC_STORAGE_TYPE": "gcs", "JAC_STORAGE_FIREBASE_PUBLIC_READ": "true"}, toml
    );
    assert storage.public_read == True;
    assert storage.bucket == "toml-bucket";
}
