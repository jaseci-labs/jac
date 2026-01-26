"""Factory for creating storage instances."""
import from typing { Any }
import os;
import from jac_scale.abstractions.storage { Storage }

"""Factory for creating storage instances."""
class StorageFactory {
    static def create(
        storage_type: str,
        config: (dict[str, Any] | None) = None
    ) -> Storage {
        if storage_type == 'local' {
            import from jac_scale.providers.storage.local_storage { LocalStorage }
            return LocalStorage(config=config or {});
        } elif storage_type == 's3' {
            raise NotImplementedError("S3 storage not yet implemented");
        } elif storage_type == 'gcs' {
            raise NotImplementedError("GCS storage not yet implemented");
        } elif storage_type == 'azure' {
            raise NotImplementedError("Azure Blob storage not yet implemented");
        } else {
            raise ValueError(f"Unsupported storage type: {storage_type}");
        }
    }

    static def get_default(config: (dict[str, Any] | None) = None) -> Storage {
        storage_type = os.environ.get('JAC_STORAGE_TYPE', 'local');
        return StorageFactory.create(storage_type, config);
    }
}
