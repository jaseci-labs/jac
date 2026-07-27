import from jaclang.runtimelib.storage.storage { Storage }

class BucketStorage(Storage) {
    has prefix: str = "";

    def _resolve_key(self: BucketStorage, path: str) -> str {
        path = path.lstrip("/");
        if self.prefix {
            return f"{self.prefix}/{path}";
        }
        return path;
    }

    def _strip_key_prefix(self: BucketStorage, key: str) -> str {
        if self.prefix and key.startswith(f"{self.prefix}/") {
            return key[len(self.prefix) + 1:];
        }
        return key;
    }

    override def move(self: BucketStorage, source: str, destination: str) -> bool {
        if self.copy(source, destination) {
            return self.delete(source);
        }
        return False;
    }
}
