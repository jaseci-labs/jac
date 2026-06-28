import from typing { BinaryIO, Generator }

class Storage {
    def upload(
        self: Storage,
        source: (str | BinaryIO),
        destination: str,
        metadata: (dict[str, str] | None) = None
    ) -> str abs;

    def download(
        self: Storage, source: str, destination: (str | BinaryIO | None) = None
    ) -> (bytes | None) abs;

    def delete(self: Storage, path: str) -> bool abs;
    def exists(self: Storage, path: str) -> bool abs;
    def list_files(
        self: Storage, prefix: str = "", recursive: bool = False
    ) -> Generator[str, None, None] abs;

    def get_metadata(self: Storage, path: str) -> dict[str, any] abs;
    def copy(self: Storage, source: str, destination: str) -> bool abs;
    def move(self: Storage, source: str, destination: str) -> bool abs;
    def get_url(self: Storage, path: str, expires_in: (int | None) = 3600) -> str abs;
}
