"""Google Cloud Storage / Firebase Storage implementation for Jac."""
import from typing { Any, BinaryIO, Generator }
import from jaclang.scale.storage.bucket_storage { BucketStorage }

"""GCS storage provider.

This implementation uses google-cloud-storage to interact with Google Cloud
Storage buckets, including Firebase Storage buckets.
"""
class GcsStorage(BucketStorage) {
    has bucket: str,
        public_read: bool = False,
        project_id: (str | None) = None,
        _client: Any = None,
        _bucket: Any = None;

    def init(
        self: GcsStorage,
        bucket: str,
        prefix: str = "",
        public_read: bool = False,
        project_id: (str | None) = None
    ) -> None;

    override def upload(
        self: GcsStorage,
        source: (str | BinaryIO),
        destination: str,
        metadata: (dict[str, str] | None) = None
    ) -> str;

    override def download(
        self: GcsStorage, source: str, destination: (str | BinaryIO | None) = None
    ) -> (bytes | None);

    override def delete(self: GcsStorage, path: str) -> bool;
    override def exists(self: GcsStorage, path: str) -> bool;
    override def list_files(
        self: GcsStorage, prefix: str = "", recursive: bool = False
    ) -> Generator[str, None, None];

    override def get_metadata(self: GcsStorage, path: str) -> dict[str, Any];
    override def copy(self: GcsStorage, source: str, destination: str) -> bool;
    override def get_url(
        self: GcsStorage, path: str, expires_in: (int | None) = 3600
    ) -> str;
}
