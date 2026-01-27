"""Factory for creating storage instances."""
import from typing { Any }
import os;
import from jaclang.runtimelib.storage { Storage }
import from jaclang.project.config { get_config }

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
        storage_type: str, config: (dict[str, Any] | None) = None
    ) -> Storage {
        if storage_type == 'local' {
            import from jaclang.runtimelib.storage { LocalStorage }
            return LocalStorage(config or {});
        } elif storage_type == 's3' {
            raise NotImplementedError("S3 storage not yet implemented") ;
        } elif storage_type == 'gcs' {
            raise NotImplementedError("GCS storage not yet implemented") ;
        } elif storage_type == 'azure' {
            raise NotImplementedError("Azure Blob storage not yet implemented") ;
        } else {
            raise ValueError(f"Unsupported storage type: {storage_type}") ;
        }
    }

    static def get_default(config: (dict[str, Any] | None) = None) -> Storage {
        # Get config from jac.toml if available
        jac_config = get_config();

        # Config priority: jac.toml > env var > default
        if jac_config and jac_config.storage {
            storage_type = jac_config.storage.storage_type;
            base_path = jac_config.storage.base_path;
            create_dirs = jac_config.storage.create_dirs;
        } else {
            storage_type = os.environ.get('JAC_STORAGE_TYPE', 'local');
            base_path = os.environ.get('JAC_STORAGE_PATH', './storage');
            create_dirs_str = os.environ.get('JAC_STORAGE_CREATE_DIRS', 'true');
            create_dirs = create_dirs_str.lower() == 'true';
        }

        storage_config = {
            'base_path': base_path,
            'create_dirs': create_dirs,
            **(config or {})
        };
        return StorageFactory.create(storage_type, storage_config);
    }
}
