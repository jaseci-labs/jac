"""Factory for creating storage instances."""
import from typing { Any }
import os;
import from jaclang.runtimelib.storage { Storage }
import from jaclang.project.config { get_config }

enum StorageType {
    LOCAL = "local"
    # Future: S3, GCS, AZURE - add when implemented
}

"""Factory for creating storage instances.

Configuration priority: jac.toml > environment variable > default

In jac.toml:
    [storage]
    type = "local"  # or "s3", "gcs", "azure"
    base_path = "/data/storage"
    create_dirs = true

Environment variables:
    JAC_STORAGE_TYPE: Storage type (local, s3, gcs, azure)
    JAC_STORAGE_PATH: Base directory for local storage
    JAC_STORAGE_CREATE_DIRS: Whether to auto-create directories
"""
class StorageFactory {
    static def create(
        storage_type: (StorageType | str), config: (dict[str, Any] | None) = None
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
        }
        raise ValueError(f"Unsupported storage type: {storage_type}") ;
    }

    static def get_default(
        base_path: str = "./storage", create_dirs: bool = True
    ) -> Storage {
        # Get config from jac.toml if available
        jac_config = get_config();

        # Config priority: jac.toml > env var > parameter
        if jac_config and jac_config.storage {
            storage_type = StorageType(jac_config.storage.storage_type);
            base_path = jac_config.storage.base_path;
            create_dirs = jac_config.storage.create_dirs;
        } elif os.environ.get("JAC_STORAGE_TYPE") or os.environ.get("JAC_STORAGE_PATH") {
            storage_type_str = os.environ.get(
                "JAC_STORAGE_TYPE", StorageType.LOCAL.value
            );
            storage_type = StorageType(storage_type_str);
            base_path = os.environ.get("JAC_STORAGE_PATH", base_path);
            create_dirs_str = os.environ.get(
                "JAC_STORAGE_CREATE_DIRS", str(create_dirs)
            );
            create_dirs = create_dirs_str.lower() == "true";
        } else {
            storage_type = StorageType.LOCAL;
        }

        storage_config = {"base_path": base_path, "create_dirs": create_dirs};
        return StorageFactory.create(storage_type, storage_config);
    }
}
