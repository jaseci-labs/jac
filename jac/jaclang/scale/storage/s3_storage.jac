import from typing { Any, BinaryIO, Generator }
import from jaclang.scale.storage.bucket_storage { BucketStorage }

class S3Storage(BucketStorage) {
    has bucket: str,
        region: str = "us-east-1",
        endpoint_url: (str | None) = None,
        public_read: bool = False,
        _client: Any = None;

    def init(
        self: S3Storage,
        bucket: str,
        prefix: str = "",
        region: str = "us-east-1",
        endpoint_url: (str | None) = None,
        public_read: bool = False
    ) -> None;

    override def upload(
        self: S3Storage,
        source: (str | BinaryIO),
        destination: str,
        metadata: (dict[str, str] | None) = None
    ) -> str;

    override def download(
        self: S3Storage, source: str, destination: (str | BinaryIO | None) = None
    ) -> (bytes | None);

    override def delete(self: S3Storage, path: str) -> bool;
    override def exists(self: S3Storage, path: str) -> bool;
    override def list_files(
        self: S3Storage, prefix: str = "", recursive: bool = False
    ) -> Generator[str, None, None];

    override def get_metadata(self: S3Storage, path: str) -> dict[str, Any];
    override def copy(self: S3Storage, source: str, destination: str) -> bool;
    override def get_url(
        self: S3Storage, path: str, expires_in: (int | None) = 3600
    ) -> str;
}
