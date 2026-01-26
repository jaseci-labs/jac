"""Base storage abstraction for jac_scale."""
import from typing { Any, BinaryIO, Generator }

"""Base class for all storage implementations."""
class Storage {
    def upload(
        self: Storage,
        source: (str | BinaryIO),
        destination: str,
        metadata: dict[str, str] = {}
    ) -> str abs;

    def download(
        self: Storage, source: str, destination: (str | BinaryIO | None) = None
    ) -> (bytes | None) abs;

    def delete(self: Storage, path: str) -> bool abs;
    def exists(self: Storage, path: str) -> bool abs;
    def list_files(
        self: Storage, prefix: str = "", recursive: bool = False
    ) -> Generator[str, None, None] abs;

    def get_metadata(self: Storage, path: str) -> dict[str, Any] abs;
    def get_url(self: Storage, path: str, expiry_seconds: int = 3600) -> str abs;
    def copy(self: Storage, source: str, destination: str) -> bool abs;
    def move(self: Storage, source: str, destination: str) -> bool abs;
    def get_info(self: Storage) -> dict[str, Any] abs;
    def is_available(self: Storage) -> bool abs;
    def close(self: Storage) -> None abs;
}
