import os;
import from jaclang.runtimelib.storage { Storage }
import from jaclang.project.config { get_config }
import from jaclang.scale.config.firebase_env {
    JAC_STORAGE_FIREBASE_PROJECT_ID_ENV,
    JAC_STORAGE_GCS_PROJECT_ID_ENV,
    resolve_firebase_project_id
}

enum StorageType { LOCAL = "local", S3 = "s3", GCS = "gcs", FIREBASE = "firebase" }

def _resolve_storage_env(suffix: str, env_prefix: str) -> (str | None) {
    other_prefix = "FIREBASE" if env_prefix == "GCS" else "GCS";
    for p in [env_prefix, other_prefix] {
        val = os.environ.get(f"JAC_STORAGE_{p}_{suffix}");
        if val {
            return val;
        }
    }
    return None;
}

class StorageFactory {
    static def default_storage_type -> StorageType {
        jac_config = get_config();
        storage_type_str = os.environ.get("JAC_STORAGE_TYPE");
        if not storage_type_str and jac_config and jac_config.storage {
            storage_type_str = jac_config.storage.storage_type;
        }
        return StorageType(storage_type_str or StorageType.LOCAL.value);
    }

    static def create(
        storage_type: (StorageType | str), config: (dict[str, any] | None) = None
    ) -> Storage {
        if isinstance(storage_type, str) {
            storage_type = StorageType(storage_type);
        }

        if storage_type == StorageType.LOCAL {
            import from jaclang.runtimelib.storage { LocalStorage }
            cfg = config or {};
            return LocalStorage(
                base_path=cfg.get("base_path", "./storage"),
                create_dirs=cfg.get("create_dirs", True)
            );
        } elif storage_type == StorageType.S3 {
            import from jaclang.scale.storage.s3_storage { S3Storage }
            cfg = config or {};
            if not cfg.get("bucket") {
                raise ValueError("S3 storage requires a 'bucket' configuration.");
            }
            return S3Storage(
                bucket=cfg["bucket"],
                prefix=cfg.get("prefix", ""),
                region=cfg.get("region", "us-east-1"),
                endpoint_url=cfg.get("endpoint_url"),
                public_read=cfg.get("public_read", False)
            );
        } elif storage_type in [StorageType.GCS, StorageType.FIREBASE] {
            import from jaclang.scale.storage.gcs_storage { GcsStorage }
            cfg = config or {};
            if not cfg.get("bucket") {
                raise ValueError(
                    "GCS/Firebase storage requires a 'bucket' configuration."
                );
            }
            return GcsStorage(
                bucket=cfg["bucket"],
                prefix=cfg.get("prefix", ""),
                public_read=cfg.get("public_read", False),
                project_id=cfg.get("project_id")
            );
        }
        raise ValueError(f"Unsupported storage type: {storage_type}");
    }

    static def get_default(
        base_path: str = "./storage", create_dirs: bool = True
    ) -> Storage {
        jac_config = get_config();
        storage_config: dict[str, any] = {};

        storage_type = StorageFactory.default_storage_type();

        if storage_type == StorageType.LOCAL {
            # Honor an explicitly-passed base_path over the project config; only
            # fall back to config when the caller left the default. This keeps
            # store(base_path=X) returning X while store() still picks up the
            # [storage] base_path from jac.toml.
            if base_path == "./storage" and jac_config and jac_config.storage {
                base_path = jac_config.storage.base_path;
                create_dirs = jac_config.storage.create_dirs;
            }
            base_path = os.environ.get("JAC_STORAGE_PATH", base_path);
            create_dirs_env = os.environ.get("JAC_STORAGE_CREATE_DIRS");
            if create_dirs_env {
                create_dirs = create_dirs_env.lower() == "true";
            }
            storage_config = {"base_path": base_path, "create_dirs": create_dirs};
        } elif storage_type == StorageType.S3 {
            if jac_config and jac_config.storage {
                storage_config["bucket"] = jac_config.storage.bucket;
                storage_config["prefix"] = jac_config.storage.prefix;
                storage_config["region"] = jac_config.storage.region;
                storage_config["endpoint_url"] = jac_config.storage.endpoint_url;
                storage_config["public_read"] = jac_config.storage.public_read;
            }
            if (bucket_env := os.environ.get("JAC_STORAGE_S3_BUCKET")) {
                storage_config["bucket"] = bucket_env;
            }
            if (prefix_env := os.environ.get("JAC_STORAGE_S3_PREFIX")) {
                storage_config["prefix"] = prefix_env;
            }
            if (region_env := os.environ.get("JAC_STORAGE_S3_REGION")) {
                storage_config["region"] = region_env;
            }
            if (endpoint_env := os.environ.get("JAC_STORAGE_S3_ENDPOINT_URL")) {
                storage_config["endpoint_url"] = endpoint_env;
            }
            if (public_env := os.environ.get("JAC_STORAGE_S3_PUBLIC_READ")) {
                storage_config["public_read"] = public_env.lower() == "true";
            }
        } elif storage_type in [StorageType.GCS, StorageType.FIREBASE] {
            if jac_config and jac_config.storage {
                storage_config["bucket"] = jac_config.storage.bucket;
                storage_config["prefix"] = jac_config.storage.prefix;
                storage_config["project_id"] = jac_config.storage.project_id;
                storage_config["public_read"] = jac_config.storage.public_read;
            }
            env_prefix = "GCS" if storage_type == StorageType.GCS else "FIREBASE";
            other_prefix = "FIREBASE" if env_prefix == "GCS" else "GCS";
            if (bucket_env := _resolve_storage_env("BUCKET", env_prefix)) {
                storage_config["bucket"] = bucket_env;
            }
            if (prefix_env := _resolve_storage_env("PREFIX", env_prefix)) {
                storage_config["prefix"] = prefix_env;
            }
            if (public_env := _resolve_storage_env("PUBLIC_READ", env_prefix)) {
                storage_config["public_read"] = public_env.lower() == "true";
            }
            if (
                resolved_project := resolve_firebase_project_id(
                    [
                        f"JAC_STORAGE_{env_prefix}_PROJECT_ID",
                        f"JAC_STORAGE_{other_prefix}_PROJECT_ID",
                        JAC_STORAGE_FIREBASE_PROJECT_ID_ENV,
                        JAC_STORAGE_GCS_PROJECT_ID_ENV
                    ],
                    storage_config.get('project_id')
                )
            ) {
                storage_config['project_id'] = resolved_project;
            }
        }

        return StorageFactory.create(storage_type, storage_config);
    }
}
