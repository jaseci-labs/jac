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
    ) -> None {
        self.base_path = base_path;
        self.create_dirs = create_dirs;
        if self.create_dirs {
            Path(self.base_path).mkdir(parents=True, exist_ok=True);
        }
    }

    """Resolve a relative path to an absolute path within the storage base."""
    def _resolve_path(self: LocalStorage, path: str) -> Path {
        return Path(self.base_path) / path.lstrip("/");
    }

    override def upload(
        self: LocalStorage,
        source: (str | BinaryIO),
        destination: str,
        metadata: (dict[str, str] | None) = None
    ) -> str {
        dest_path = self._resolve_path(destination);
        dest_path.parent.mkdir(parents=True, exist_ok=True);
        if isinstance(source, str) {
            shutil.copy2(source, dest_path);
        } else {
            with open(dest_path, "wb") as f {
                content = source.read();
                f.write(content if isinstance(content, bytes) else content);
            }
        }
        return str(dest_path);
    }

    override def download(
        self: LocalStorage, source: str, destination: (str | BinaryIO | None) = None
    ) -> (bytes | None) {
        src_path = self._resolve_path(source);
        if not src_path.exists() {
            raise FileNotFoundError(f"File not found: {source}") ;
        }
        if destination is None {
            with open(src_path, "rb") as f {
                return f.read();
            }
        } elif isinstance(destination, str) {
            shutil.copy2(src_path, destination);
            return None;
        } else {
            with open(src_path, "rb") as f {
                destination.write(f.read());
            }
            return None;
        }
    }

    override def delete(self: LocalStorage, path: str) -> bool {
        file_path = self._resolve_path(path);
        if file_path.exists() {
            if file_path.is_dir() {
                shutil.rmtree(file_path);
            } else {
                file_path.unlink();
            }
            return True;
        }
        return False;
    }

    override def exists(self: LocalStorage, path: str) -> bool {
        return self._resolve_path(path).exists();
    }

    override def list_files(
        self: LocalStorage, prefix: str = "", recursive: bool = False
    ) -> Generator[str, None, None] {
        base = self._resolve_path(prefix) if prefix else Path(self.base_path);
        if base.exists() {
            if recursive {
                for item in base.rglob("*") {
                    if item.is_file() {
                        yield str(item.relative_to(self.base_path));
                    }
                }
            } else {
                for item in base.iterdir() {
                    yield str(item.relative_to(self.base_path));
                }
            }
        }
    }

    override def get_metadata(self: LocalStorage, path: str) -> dict[str, Any] {
        file_path = self._resolve_path(path);
        if not file_path.exists() {
            raise FileNotFoundError(f"File not found: {path}") ;
        }
        stat = file_path.stat();
        return {
            "size": stat.st_size,
            "modified": stat.st_mtime,
            "created": stat.st_ctime,
            "is_dir": file_path.is_dir(),
            "name": file_path.name
        };
    }

    override def copy(self: LocalStorage, source: str, destination: str) -> bool {
        src_path = self._resolve_path(source);
        dest_path = self._resolve_path(destination);
        if not src_path.exists() {
            return False;
        }
        dest_path.parent.mkdir(parents=True, exist_ok=True);
        shutil.copy2(src_path, dest_path);
        return True;
    }

    override def move(self: LocalStorage, source: str, destination: str) -> bool {
        src_path = self._resolve_path(source);
        dest_path = self._resolve_path(destination);
        if not src_path.exists() {
            return False;
        }
        dest_path.parent.mkdir(parents=True, exist_ok=True);
        shutil.move(str(src_path), str(dest_path));
        return True;
    }
}
