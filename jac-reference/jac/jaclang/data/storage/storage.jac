import from typing { BinaryIO, Generator }

class Storage {
    def upload(
        self: Storage,
        source: (str | BinaryIO),
        destination: str,
        metadata: (dict[str, str] | None) = None
    ) -> str abst;

    def download(
        self: Storage, source: str, destination: (str | BinaryIO | None) = None
    ) -> (bytes | None) abst;

    def delete(self: Storage, path: str) -> bool abst;
    def exists(self: Storage, path: str) -> bool abst;
    def list_files(
        self: Storage, prefix: str = "", recursive: bool = False
    ) -> Generator[str, None, None] abst;

    def get_metadata(self: Storage, path: str) -> dict[str, any] abst;
    def copy(self: Storage, source: str, destination: str) -> bool abst;
    def move(self: Storage, source: str, destination: str) -> bool abst;
    def get_url(self: Storage, path: str, expires_in: (int | None) = 3600) -> str abst;
}
