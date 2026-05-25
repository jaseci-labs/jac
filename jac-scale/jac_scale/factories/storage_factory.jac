"""Factory for creating storage instances."""
import os;
import from jaclang.runtimelib.storage { Storage }
import from jaclang.project.config { get_config }

enum StorageType {
    LOCAL = "local",
    S3 = "s3"
    # Future: GCS, AZURE
}

"""Factory for creating storage instances.

Configuration priority: jac.toml > environment variable > default

In jac.toml:
    [storage]
    storage_type = "s3"  # or "local"
    bucket = "my-bucket"
    region = "us-east-1"
    prefix = "uploads/"
    public_read = false
    endpoint_url = "https://..." # optional

Environment variables:
    JAC_STORAGE_TYPE: local, s3
    JAC_STORAGE_S3_BUCKET: S3 bucket name
    JAC_STORAGE_S3_REGION: AWS region
    JAC_STORAGE_S3_PREFIX: Key prefix
    JAC_STORAGE_S3_ENDPOINT_URL: For S3-compatible providers
    JAC_STORAGE_S3_PUBLIC_READ: "true" or "false"
"""
class StorageFactory {
    static def create(
        storage_type: (StorageType | str), config: (dict[str, any] | None) = None
    ) -> Storage {
        # Convert string to enum if needed
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
            import from jac_scale.storage.s3_storage { S3Storage }
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
        }
        raise ValueError(f"Unsupported storage type: {storage_type}");
    }

    static def get_default(
        base_path: str = "./storage", create_dirs: bool = True
    ) -> Storage {
        # Get config from jac.toml if available
        jac_config = get_config();
        storage_config: dict[str, Any] = {};

        # 1. Determine storage type
        storage_type_str = os.environ.get("JAC_STORAGE_TYPE");
        if not storage_type_str and jac_config and jac_config.storage {
            storage_type_str = jac_config.storage.storage_type;
        }
        storage_type = StorageType(storage_type_str or StorageType.LOCAL.value);

        # 2. Gather configuration based on type
        if storage_type == StorageType.LOCAL {
            if jac_config and jac_config.storage {
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
            # Environment variable overrides
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
        }

        return StorageFactory.create(storage_type, storage_config);
    }
}
