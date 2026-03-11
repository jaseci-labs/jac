"""Local filesystem storage implementation for Jac core."""
import shutil;
import from pathlib { Path }
import from typing { Any, BinaryIO, Generator }
import from jaclang.runtimelib.storage.storage { Storage }

"""Local filesystem storage provider.

This is the default storage implementation that stores files on the local
filesystem. Plugins like jac-scale can override store() to provide
cloud storage backends instead.
"""
class LocalStorage(Storage) {
    has base_path: str = "./storage",
        create_dirs: bool = True;

    def init(
        self: LocalStorage, base_path: str = "./storage", create_dirs: bool = True
    ) -> None;

    """Resolve a relative path to an absolute path within the storage base."""
    def _resolve_path(self: LocalStorage, path: str) -> Path;

    override def upload(
        self: LocalStorage,
        source: (str | BinaryIO),
        destination: str,
        metadata: (dict[str, str] | None) = None
    ) -> str;

    override def download(
        self: LocalStorage, source: str, destination: (str | BinaryIO | None) = None
    ) -> (bytes | None);

    override def delete(self: LocalStorage, path: str) -> bool;
    override def exists(self: LocalStorage, path: str) -> bool;
    override def list_files(
        self: LocalStorage, prefix: str = "", recursive: bool = False
    ) -> Generator[str, None, None];

    override def get_metadata(self: LocalStorage, path: str) -> dict[str, Any];
    override def copy(self: LocalStorage, source: str, destination: str) -> bool;
    override def move(self: LocalStorage, source: str, destination: str) -> bool;
}
