import os;

enum StorageType { LOCAL = "local", S3 = "s3", GCS = "gcs", FIREBASE = "firebase" }

def _resolve_storage_env(suffix: str, env_prefix: str) -> (str | None);

class StorageFactory {
    static def default_storage_type -> StorageType;
    static def create(
        storage_type: (StorageType | str), config: (dict[str, any] | None) = None
    ) -> Storage;

    static def get_default(
        base_path: str = "./storage", create_dirs: bool = True
    ) -> Storage;
}
