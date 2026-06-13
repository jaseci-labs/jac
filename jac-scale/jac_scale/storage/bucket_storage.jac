"""Shared base for prefixed object-bucket storage backends (S3, GCS).

Object stores share two pieces of behavior that are independent of the
vendor SDK: resolving a relative path against a configured key prefix, and
implementing `move` as copy-then-delete. Concrete backends (S3Storage,
GcsStorage) inherit those here and only implement the vendor-specific I/O.
"""
import from jaclang.runtimelib.storage.storage { Storage }

"""Storage backend addressing a single bucket under an optional key prefix.

Concrete subclasses own the bucket handle / vendor client and the per-object
I/O; this base supplies only the prefix-aware key resolution and the
copy-then-delete `move` that both S3 and GCS share verbatim.
"""
class BucketStorage(Storage) {
    has prefix: str = "";

    """Resolve a relative path to an object key with the configured prefix."""
    def _resolve_key(self: BucketStorage, path: str) -> str {
        path = path.lstrip("/");
        if self.prefix {
            return f"{self.prefix}/{path}";
        }
        return path;
    }

    """Move a file by copying it to the destination then deleting the source.

    Note: `delete()` returns True on S3 unconditionally (DeleteObject is
    idempotent) but False on GCS when the key is absent — callers should
    treat the bool as best-effort rather than a reliable "did it exist" signal.
    `move` is unaffected because `copy` already verified the source exists.
    """
    override def move(self: BucketStorage, source: str, destination: str) -> bool {
        if self.copy(source, destination) {
            return self.delete(source);
        }
        return False;
    }
}
