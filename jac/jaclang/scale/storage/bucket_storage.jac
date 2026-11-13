class BucketStorage(Storage) {
    has prefix: str = "";

    def _resolve_key(self: BucketStorage, path: str) -> str;
    def _strip_key_prefix(self: BucketStorage, key: str) -> str;
    override def move(self: BucketStorage, source: str, destination: str) -> bool;
}
